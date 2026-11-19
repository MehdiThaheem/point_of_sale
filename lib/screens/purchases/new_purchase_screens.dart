import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../models/raw_material.dart';
import '../../models/supplier.dart';
import '../../services/branch_service.dart';
import '../../services/product_service.dart';
import '../../services/purchase_service.dart';
import '../../services/raw_material_service.dart';
import '../../services/supplier_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/pro_ui.dart';

class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  final PurchaseService _purchaseService = PurchaseService();

  List<Branch> _branches = [];
  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  List<RawMaterial> _rawMaterials = [];
  final List<StreamSubscription> _subs = [];

  String? _branchId;
  String? _supplierId;
  final List<PurchaseItem> _items = [];
  final TextEditingController _paidController =
  TextEditingController(text: '0');
  bool _saving = false;

  double get _total => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _paid => double.tryParse(_paidController.text.trim()) ?? 0;
  double get _due => _total - _paid;

  @override
  void initState() {
    super.initState();
    // Start on the branch chosen in the top bar (if any).
    _branchId = selectedBranchId.value;

    void listen<T>(Stream<T> stream, void Function(T) assign) {
      _subs.add(stream.listen((d) {
        if (!mounted) return;
        setState(() => assign(d));
      }, onError: (_) {}));
    }

    listen(BranchService().streamBranches(), (d) => _branches = d);
    listen(SupplierService().streamSuppliers(), (d) => _suppliers = d);
    listen(ProductService().streamProducts(), (d) => _products = d);
    listen(RawMaterialService().streamRawMaterials(),
            (d) => _rawMaterials = d);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _paidController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    if (_branchId == null) {
      Pro.snack(context, 'Select a branch first.');
      return;
    }
    // Only this branch's products and raw materials can be purchased.
    final products = _products.where((p) => p.branchId == _branchId).toList();
    final raws =
    _rawMaterials.where((r) => r.branchId == _branchId).toList();

    final item = await showDialog<PurchaseItem>(
      context: context,
      builder: (_) => _AddItemDialog(products: products, rawMaterials: raws),
    );
    if (item != null && mounted) {
      setState(() => _items.add(item));
    }
  }

  Future<void> _submit() async {
    if (_branchId == null) {
      Pro.snack(context, 'Select a branch.');
      return;
    }
    if (_supplierId == null) {
      Pro.snack(context, 'Select a supplier.');
      return;
    }
    if (_items.isEmpty) {
      Pro.snack(context, 'Add at least one item.');
      return;
    }
    if (_paid < 0 || _paid > _total) {
      Pro.snack(context, 'Paid amount must be between 0 and the total.');
      return;
    }

    var branchName = '';
    for (final b in _branches) {
      if (b.id == _branchId) branchName = b.name;
    }
    var supplierName = '';
    for (final s in _suppliers) {
      if (s.id == _supplierId) supplierName = s.name;
    }

    setState(() => _saving = true);

    final purchase = Purchase(
      id: '',
      supplierId: _supplierId!,
      supplierName: supplierName,
      items: List.of(_items),
      totalAmount: _total,
      paidAmount: _paid,
      branchId: _branchId!,
      branchName: branchName,
    );

    try {
      await _purchaseService.addPurchase(purchase);
      if (mounted) {
        Pro.snack(context, 'Purchase saved.', color: Pro.green);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        Pro.snack(context, 'Error: $e');
      }
    }
  }

  // ---------- pieces ----------

  Widget _sectionTitle(String title, IconData icon, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Pro.head),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );

  Widget _summaryBox(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Pro.grey, fontSize: 12)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(Pro.money(value),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchValue =
    _branches.any((b) => b.id == _branchId) ? _branchId : null;
    final supplierValue =
    _suppliers.any((s) => s.id == _supplierId) ? _supplierId : null;
    final overpaid = _paid > _total;

    final branchField = DropdownButtonFormField<String>(
      value: branchValue,
      isExpanded: true,
      decoration: _deco('Branch'),
      items: [
        for (final b in _branches)
          DropdownMenuItem(value: b.id, child: Text(b.name)),
      ],
      onChanged: (v) => setState(() {
        if (v != _branchId) _items.clear(); // items belong to one branch
        _branchId = v;
      }),
    );

    final supplierField = DropdownButtonFormField<String>(
      value: supplierValue,
      isExpanded: true,
      decoration: _deco('Supplier'),
      items: [
        for (final s in _suppliers)
          DropdownMenuItem(value: s.id, child: Text(s.name)),
      ],
      onChanged: (v) => setState(() => _supplierId = v),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('New Purchase'),
        backgroundColor: Pro.navy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- details ----
                ProCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                          'Purchase Details', Icons.info_outline_rounded),
                      LayoutBuilder(builder: (context, c) {
                        if (c.maxWidth < 560) {
                          return Column(children: [
                            branchField,
                            const SizedBox(height: 14),
                            supplierField,
                          ]);
                        }
                        return Row(
                          children: [
                            Expanded(child: branchField),
                            const SizedBox(width: 16),
                            Expanded(child: supplierField),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ---- items ----
                ProCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                        'Items',
                        Icons.inventory_2_outlined,
                        trailing: Pro.button(
                            'Add Item', Icons.add, _addItem),
                      ),
                      ProTable(
                        minWidth: 640,
                        emptyText: 'No items added yet. Tap "Add Item".',
                        columns: const [
                          ProCol('Sr#', 7, align: Alignment.center),
                          ProCol('Item', 30),
                          ProCol('Type', 15),
                          ProCol('Qty', 11, align: Alignment.centerRight),
                          ProCol('Unit Cost', 14,
                              align: Alignment.centerRight),
                          ProCol('Subtotal', 15,
                              align: Alignment.centerRight),
                          ProCol('', 8, align: Alignment.center),
                        ],
                        rows: [
                          for (var i = 0; i < _items.length; i++)
                            [
                              Pro.t('${i + 1}', align: TextAlign.center),
                              Pro.t(_items[i].itemName, bold: true),
                              Pro.t(_items[i].itemType == 'raw_material'
                                  ? 'Raw Material'
                                  : 'Product'),
                              Pro.t(Pro.qty(_items[i].quantity),
                                  align: TextAlign.right),
                              Pro.t(
                                  Pro.money(_items[i].unitCost, decimals: 2),
                                  align: TextAlign.right),
                              Pro.t(Pro.money(_items[i].subtotal),
                                  bold: true, align: TextAlign.right),
                              IconButton(
                                tooltip: 'Remove',
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    setState(() => _items.removeAt(i)),
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: Pro.red),
                              ),
                            ],
                        ],
                        footer: [
                          const SizedBox(),
                          Pro.t('Total', bold: true),
                          const SizedBox(),
                          const SizedBox(),
                          const SizedBox(),
                          Pro.t(Pro.money(_total),
                              bold: true, align: TextAlign.right),
                          const SizedBox(),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ---- payment ----
                ProCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Payment', Icons.payments_outlined),
                      TextField(
                        controller: _paidController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                        decoration: _deco('Paid Amount').copyWith(
                          errorText: overpaid
                              ? 'Paid amount cannot be more than the total.'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _summaryBox('Total', _total, Pro.blue),
                          const SizedBox(width: 12),
                          _summaryBox('Paid', _paid, Pro.green),
                          const SizedBox(width: 12),
                          _summaryBox(
                              'Due', _due, _due > 0 ? Pro.red : Pro.green),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Pro.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save Purchase',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// Add Item dialog - owns its own controllers, returns a PurchaseItem.
// ==================================================================

class _Opt {
  final String id;
  final String name;
  final double cost;
  final String unit;
  const _Opt(this.id, this.name, this.cost, this.unit);

  @override
  bool operator ==(Object other) => other is _Opt && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class _AddItemDialog extends StatefulWidget {
  final List<Product> products;
  final List<RawMaterial> rawMaterials;
  const _AddItemDialog({required this.products, required this.rawMaterials});

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final TextEditingController _qty = TextEditingController(text: '1');
  final TextEditingController _cost = TextEditingController(text: '0');
  String _type = 'product'; // product / raw_material
  _Opt? _selected;
  String? _error;

  List<_Opt> get _options => _type == 'product'
      ? [
    for (final p in widget.products)
      _Opt(p.id, p.name, p.purchasePrice, p.unit)
  ]
      : [
    for (final r in widget.rawMaterials)
      _Opt(r.id, r.name, r.costPerUnit, r.unit)
  ];

  @override
  void initState() {
    super.initState();
    _pickFirst();
  }

  @override
  void dispose() {
    _qty.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _pickFirst() {
    final list = _options;
    _selected = list.isEmpty ? null : list.first;
    _cost.text = _selected == null ? '0' : Pro.qty(_selected!.cost);
  }

  double get _q => double.tryParse(_qty.text.trim()) ?? 0;
  double get _c => double.tryParse(_cost.text.trim()) ?? 0;

  void _submit() {
    if (_selected == null) {
      setState(() => _error = 'Select an item first.');
      return;
    }
    if (_q <= 0) {
      setState(() => _error = 'Enter a quantity greater than 0.');
      return;
    }
    if (_c < 0) {
      setState(() => _error = 'Unit cost cannot be negative.');
      return;
    }
    Navigator.of(context).pop(PurchaseItem(
      itemType: _type,
      itemId: _selected!.id,
      itemName: _selected!.name,
      quantity: _q,
      unitCost: _c,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final value = options.contains(_selected) ? _selected : null;

    return ProDialog(
      title: 'Add Item',
      icon: Icons.add_shopping_cart_outlined,
      width: 440,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Add')),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'product', label: Text('Product')),
              ButtonSegment(
                  value: 'raw_material', label: Text('Raw Material')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _error = null;
              _pickFirst();
            }),
          ),
          const SizedBox(height: 16),
          if (options.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No items found for this branch in this category.',
                  style: TextStyle(color: Pro.grey)),
            )
          else
            DropdownButtonFormField<_Opt>(
              value: value,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Item', border: OutlineInputBorder()),
              items: [
                for (final o in options)
                  DropdownMenuItem(value: o, child: Text(o.name)),
              ],
              onChanged: (v) => setState(() {
                _selected = v;
                _cost.text = v == null ? '0' : Pro.qty(v.cost);
                _error = null;
              }),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qty,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _error = null),
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    suffixText: _selected?.unit,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cost,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _error = null),
                  decoration: const InputDecoration(
                    labelText: 'Unit Cost',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Pro.tint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Subtotal: ${Pro.money(_q * _c, decimals: 2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Pro.red)),
          ],
        ],
      ),
    );
  }
}