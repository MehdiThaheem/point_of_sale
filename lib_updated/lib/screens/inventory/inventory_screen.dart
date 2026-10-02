import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/raw_material.dart';
import '../../services/product_service.dart';
import '../../services/raw_material_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/pro_ui.dart';

// One row of the table (a product or a raw material).
class _Item {
  final String id;
  final String name;
  final String category;
  final String unit;
  final double stock;
  final double min;
  final bool isRaw;

  const _Item(this.id, this.name, this.category, this.unit, this.stock,
      this.min, this.isRaw);

  bool get isOut => stock <= 0;
  bool get isLow => !isOut && stock <= min;

  String get statusLabel => isOut ? 'Out of Stock' : (isLow ? 'Low Stock' : 'In Stock');
  Color get statusColor => isOut ? Pro.red : (isLow ? Pro.orange : Pro.green);
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final ProductService _productService = ProductService();
  final RawMaterialService _rawService = RawMaterialService();

  List<Product> _products = [];
  List<RawMaterial> _raws = [];
  bool _loadedProducts = false;
  bool _loadedRaws = false;
  final List<StreamSubscription> _subs = [];

  final TextEditingController _search = TextEditingController();
  String _tab = 'products'; // products / raw
  String _filter = 'All'; // All / Low Stock / Out of Stock

  @override
  void initState() {
    super.initState();
    _subs.add(_productService.streamProducts().listen((d) {
      if (!mounted) return;
      setState(() {
        _products = d;
        _loadedProducts = true;
      });
    }, onError: (_) {}));
    _subs.add(_rawService.streamRawMaterials().listen((d) {
      if (!mounted) return;
      setState(() {
        _raws = d;
        _loadedRaws = true;
      });
    }, onError: (_) {}));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _search.dispose();
    super.dispose();
  }

  // ---------- actions ----------

  Future<void> _adjust(_Item item) async {
    final delta = await showDialog<double>(
      context: context,
      builder: (_) => _AdjustDialog(item: item),
    );
    if (delta == null || !mounted) return;

    try {
      if (item.isRaw) {
        await _rawService.adjustStock(item.id, delta);
      } else {
        await _productService.adjustStock(item.id, delta);
      }
      if (mounted) {
        Pro.snack(
          context,
          'Stock of "${item.name}" ${delta >= 0 ? 'increased' : 'reduced'} '
              'by ${Pro.qty(delta.abs())} ${item.unit}.',
          color: Pro.green,
        );
      }
    } catch (e) {
      if (mounted) Pro.snack(context, 'Error: $e');
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    // Products and raw materials follow the branch chosen in the top bar.
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchId, _) {
        final isProducts = _tab == 'products';

        final all = isProducts
            ? [
          for (final p in _products)
            if (branchId == null || p.branchId == branchId)
              _Item(p.id, p.name, p.categoryName, p.unit, p.currentStock,
                  p.minStock, false)
        ]
            : [
          for (final r in _raws)
            if (branchId == null || r.branchId == branchId)
              _Item(r.id, r.name, '', r.unit, r.currentStock, r.minStock,
                  true)
        ];

        final loading = isProducts ? !_loadedProducts : !_loadedRaws;

        final q = _search.text.trim().toLowerCase();
        final list = all.where((i) {
          if (q.isNotEmpty &&
              !i.name.toLowerCase().contains(q) &&
              !i.category.toLowerCase().contains(q)) {
            return false;
          }
          if (_filter == 'Low Stock' && !i.isLow) return false;
          if (_filter == 'Out of Stock' && !i.isOut) return false;
          return true;
        }).toList();

        final inStock = all.where((i) => !i.isOut && !i.isLow).length;
        final low = all.where((i) => i.isLow).length;
        final out = all.where((i) => i.isOut).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProHeader(
              title: 'Stock Adjustment',
              subtitle: selectedBranchName.value ?? 'All Branches',
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'products',
                    label: Text('Products'),
                    icon: Icon(Icons.inventory_2_outlined)),
                ButtonSegment(
                    value: 'raw',
                    label: Text('Raw Materials'),
                    icon: Icon(Icons.grain_outlined)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() {
                _tab = s.first;
                _filter = 'All';
              }),
            ),
            const SizedBox(height: 16),
            ProStatRow([
              ProStat('Total Items', '${all.length}',
                  Icons.inventory_outlined, Pro.blue),
              ProStat('In Stock', '$inStock', Icons.check_circle_outline,
                  Pro.green),
              ProStat('Low Stock', '$low', Icons.warning_amber_rounded,
                  Pro.orange),
              ProStat('Out of Stock', '$out',
                  Icons.remove_shopping_cart_outlined, Pro.red),
            ]),
            const SizedBox(height: 18),
            ProCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ProSearch(
                        controller: _search,
                        hint: isProducts
                            ? 'Search product or category...'
                            : 'Search raw material...',
                        onChanged: (_) => setState(() {}),
                      ),
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Pro.line),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _filter,
                            items: const [
                              DropdownMenuItem(
                                  value: 'All', child: Text('All Items')),
                              DropdownMenuItem(
                                  value: 'Low Stock',
                                  child: Text('Low Stock')),
                              DropdownMenuItem(
                                  value: 'Out of Stock',
                                  child: Text('Out of Stock')),
                            ],
                            onChanged: (v) =>
                                setState(() => _filter = v ?? 'All'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ProTable(
                      minWidth: isProducts ? 880 : 760,
                      emptyText: all.isEmpty
                          ? (isProducts
                          ? 'No products found for this branch.'
                          : 'No raw materials found for this branch.')
                          : 'No items match these filters.',
                      columns: [
                        const ProCol('Sr#', 6, align: Alignment.center),
                        const ProCol('Name', 24),
                        if (isProducts) const ProCol('Category', 15),
                        const ProCol('Unit', 8),
                        const ProCol('Stock', 11,
                            align: Alignment.centerRight),
                        const ProCol('Min Stock', 11,
                            align: Alignment.centerRight),
                        const ProCol('Status', 14, align: Alignment.center),
                        const ProCol('Action', 13, align: Alignment.center),
                      ],
                      rows: [
                        for (var i = 0; i < list.length; i++)
                          [
                            Pro.t('${i + 1}', align: TextAlign.center),
                            Pro.t(list[i].name, bold: true),
                            if (isProducts)
                              Pro.t(list[i].category.isEmpty
                                  ? '-'
                                  : list[i].category),
                            Pro.t(list[i].unit),
                            Pro.t(Pro.qty(list[i].stock),
                                bold: true,
                                align: TextAlign.right,
                                color: list[i].isOut || list[i].isLow
                                    ? list[i].statusColor
                                    : null),
                            Pro.t(Pro.qty(list[i].min),
                                align: TextAlign.right),
                            ProChip(list[i].statusLabel,
                                list[i].statusColor),
                            OutlinedButton.icon(
                              onPressed: () => _adjust(list[i]),
                              icon: const Icon(Icons.tune, size: 16),
                              label: const Text('Adjust'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: Pro.blue,
                              ),
                            ),
                          ],
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==================================================================
// Adjust dialog - owns its controller, returns the stock change.
// ==================================================================

class _AdjustDialog extends StatefulWidget {
  final _Item item;
  const _AdjustDialog({required this.item});

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final TextEditingController _qty = TextEditingController();
  String _mode = 'add'; // add / reduce
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  double get _q => double.tryParse(_qty.text.trim()) ?? 0;
  double get _delta => _mode == 'add' ? _q : -_q;
  double get _newStock => widget.item.stock + _delta;

  void _submit() {
    if (_q <= 0) {
      setState(() => _error = 'Enter a quantity greater than 0.');
      return;
    }
    if (_mode == 'reduce' && _q > widget.item.stock) {
      setState(() => _error =
      'Cannot reduce more than the current stock (${Pro.qty(widget.item.stock)}).');
      return;
    }
    Navigator.of(context).pop(_delta);
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final preview = _q > 0;

    return ProDialog(
      title: 'Adjust Stock',
      icon: Icons.tune,
      width: 420,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Apply')),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(it.name,
              style:
              const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Current stock: ${Pro.qty(it.stock)} ${it.unit}',
              style: const TextStyle(color: Pro.grey)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'add',
                    label: Text('Add Stock'),
                    icon: Icon(Icons.add)),
                ButtonSegment(
                    value: 'reduce',
                    label: Text('Reduce Stock'),
                    icon: Icon(Icons.remove)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qty,
            autofocus: true,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Quantity',
              suffixText: it.unit,
              border: const OutlineInputBorder(),
            ),
          ),
          if (preview) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Pro.tint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'New stock: ${Pro.qty(_newStock)} ${it.unit}',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: _newStock < 0 ? Pro.red : Colors.black87),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Pro.red)),
          ],
        ],
      ),
    );
  }
}