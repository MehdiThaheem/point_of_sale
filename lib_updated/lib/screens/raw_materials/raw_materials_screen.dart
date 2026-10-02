import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../models/raw_material.dart';
import '../../services/branch_service.dart';
import '../../services/raw_material_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/pro_ui.dart';

class RawMaterialsScreen extends StatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  State<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends State<RawMaterialsScreen> {
  final RawMaterialService _service = RawMaterialService();
  final TextEditingController _search = TextEditingController();
  String _filter = 'All'; // All / Low Stock / Out of Stock

  List<Branch> _branches = [];
  StreamSubscription? _branchSub;

  @override
  void initState() {
    super.initState();
    _branchSub = BranchService().streamBranches().listen((d) {
      if (!mounted) return;
      setState(() => _branches = d);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _branchSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  bool _isOut(RawMaterial r) => r.currentStock <= 0;
  bool _isLow(RawMaterial r) => !_isOut(r) && r.isLowStock;

  String _statusLabel(RawMaterial r) =>
      _isOut(r) ? 'Out of Stock' : (_isLow(r) ? 'Low Stock' : 'In Stock');

  Color _statusColor(RawMaterial r) =>
      _isOut(r) ? Pro.red : (_isLow(r) ? Pro.orange : Pro.green);

  // ---------- actions ----------

  Future<void> _openForm({RawMaterial? item}) async {
    final result = await showDialog<RawMaterial>(
      context: context,
      builder: (_) => _RawMaterialForm(item: item, branches: _branches),
    );
    if (result == null || !mounted) return;

    try {
      if (item == null) {
        await _service.addRawMaterial(result);
      } else {
        await _service.updateRawMaterial(item.id, result);
      }
      if (mounted) {
        Pro.snack(
            context, item == null ? 'Raw material added.' : 'Changes saved.',
            color: Pro.green);
      }
    } catch (e) {
      if (mounted) Pro.snack(context, 'Error: $e');
    }
  }

  Future<void> _delete(RawMaterial item) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Raw Material',
      message: 'Are you sure you want to delete "${item.name}"?',
    );
    if (!ok) return;
    try {
      await _service.deleteRawMaterial(item.id);
      if (mounted) Pro.snack(context, 'Deleted.', color: Pro.green);
    } catch (e) {
      if (mounted) Pro.snack(context, 'Error: $e');
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    // Follows the branch chosen in the top bar.
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchId, _) {
        return StreamBuilder<List<RawMaterial>>(
          stream: _service.streamRawMaterials(),
          builder: (context, snapshot) {
            final loading =
                snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

            final all = (snapshot.data ?? <RawMaterial>[])
                .where((r) => branchId == null || r.branchId == branchId)
                .toList();

            final q = _search.text.trim().toLowerCase();
            final list = all.where((r) {
              if (q.isNotEmpty && !r.name.toLowerCase().contains(q)) {
                return false;
              }
              if (_filter == 'Low Stock' && !_isLow(r)) return false;
              if (_filter == 'Out of Stock' && !_isOut(r)) return false;
              return true;
            }).toList();

            final value = all.fold<double>(
                0, (s, r) => s + r.currentStock * r.costPerUnit);
            final low = all.where(_isLow).length;
            final out = all.where(_isOut).length;
            final showBranch = branchId == null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProHeader(
                  title: 'Raw Materials',
                  subtitle: selectedBranchName.value ?? 'All Branches',
                  actions: [
                    Pro.button(
                        'Add Raw Material', Icons.add, () => _openForm()),
                  ],
                ),
                const SizedBox(height: 18),
                ProStatRow([
                  ProStat('Total Items', '${all.length}',
                      Icons.grain_outlined, Pro.blue),
                  ProStat('Stock Value', Pro.money(value),
                      Icons.account_balance_wallet_outlined, Pro.green),
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
                            hint: 'Search raw material...',
                            onChanged: (_) => setState(() {}),
                          ),
                          Container(
                            height: 42,
                            padding:
                            const EdgeInsets.symmetric(horizontal: 12),
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
                          minWidth: showBranch ? 1000 : 900,
                          emptyText: all.isEmpty
                              ? 'No raw materials for this branch yet. Tap "Add Raw Material".'
                              : 'No raw materials match these filters.',
                          columns: [
                            const ProCol('Sr#', 6, align: Alignment.center),
                            const ProCol('Name', 20),
                            if (showBranch) const ProCol('Branch', 12),
                            const ProCol('Unit', 8),
                            const ProCol('Stock', 10,
                                align: Alignment.centerRight),
                            const ProCol('Min Stock', 10,
                                align: Alignment.centerRight),
                            const ProCol('Cost / Unit', 11,
                                align: Alignment.centerRight),
                            const ProCol('Value', 11,
                                align: Alignment.centerRight),
                            const ProCol('Status', 12,
                                align: Alignment.center),
                            const ProCol('Action', 11,
                                align: Alignment.center),
                          ],
                          rows: [
                            for (var i = 0; i < list.length; i++)
                              _row(i, list[i], showBranch),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _row(int i, RawMaterial r, bool showBranch) {
    final color = _statusColor(r);
    return [
      Pro.t('${i + 1}', align: TextAlign.center),
      Pro.t(r.name, bold: true),
      if (showBranch) Pro.t(r.branchName.isEmpty ? '-' : r.branchName),
      Pro.t(r.unit),
      Pro.t(Pro.qty(r.currentStock),
          align: TextAlign.right,
          bold: true,
          color: color == Pro.green ? null : color),
      Pro.t(Pro.qty(r.minStock), align: TextAlign.right),
      Pro.t(Pro.money(r.costPerUnit, decimals: 2), align: TextAlign.right),
      Pro.t(Pro.money(r.currentStock * r.costPerUnit),
          align: TextAlign.right),
      ProChip(_statusLabel(r), color),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            onPressed: () => _openForm(item: r),
            icon: const Icon(Icons.edit_outlined, size: 20, color: Pro.blue),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            onPressed: () => _delete(r),
            icon: const Icon(Icons.delete_outline, size: 20, color: Pro.red),
          ),
        ],
      ),
    ];
  }
}

// ==================================================================
// Add / Edit dialog - owns its controllers, returns a RawMaterial.
// ==================================================================

class _RawMaterialForm extends StatefulWidget {
  final RawMaterial? item;
  final List<Branch> branches;
  const _RawMaterialForm({this.item, required this.branches});

  @override
  State<_RawMaterialForm> createState() => _RawMaterialFormState();
}

class _RawMaterialFormState extends State<_RawMaterialForm> {
  static const _units = [
    'kg', 'g', 'litre', 'ml', 'pcs', 'box', 'packet', 'dozen', 'meter',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _stock;
  late final TextEditingController _min;
  late final TextEditingController _cost;
  late String _unit;
  String? _branchId;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _name = TextEditingController(text: it?.name ?? '');
    _stock = TextEditingController(text: Pro.qty(it?.currentStock ?? 0));
    _min = TextEditingController(text: Pro.qty(it?.minStock ?? 0));
    _cost = TextEditingController(text: Pro.qty(it?.costPerUnit ?? 0));
    _unit = (it?.unit.isNotEmpty ?? false) ? it!.unit : 'kg';
    // New item -> the branch picked in the top bar; old item -> its own.
    final existing = it?.branchId ?? '';
    _branchId = existing.isNotEmpty ? existing : selectedBranchId.value;
  }

  @override
  void dispose() {
    _name.dispose();
    _stock.dispose();
    _min.dispose();
    _cost.dispose();
    super.dispose();
  }

  String? _numberValidator(String? v) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Cannot be negative';
    return null;
  }

  double _n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    var branchName = '';
    for (final b in widget.branches) {
      if (b.id == _branchId) branchName = b.name;
    }

    Navigator.of(context).pop(RawMaterial(
      id: widget.item?.id ?? '',
      name: _name.text.trim(),
      unit: _unit,
      currentStock: _n(_stock),
      minStock: _n(_min),
      costPerUnit: _n(_cost),
      branchId: _branchId ?? '',
      branchName: branchName,
      createdAt: widget.item?.createdAt,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    final units = _units.contains(_unit) ? _units : [..._units, _unit];
    final branchValue =
    widget.branches.any((b) => b.id == _branchId) ? _branchId : null;

    const border = OutlineInputBorder();

    return ProDialog(
      title: editing ? 'Edit Raw Material' : 'Add Raw Material',
      icon: Icons.grain_outlined,
      width: 480,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(editing ? 'Save Changes' : 'Add'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: branchValue,
              isExpanded: true,
              decoration:
              const InputDecoration(labelText: 'Branch', border: border),
              items: [
                for (final b in widget.branches)
                  DropdownMenuItem(value: b.id, child: Text(b.name)),
              ],
              onChanged: (v) => setState(() => _branchId = v),
              validator: (v) => v == null ? 'Select a branch' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration:
              const InputDecoration(labelText: 'Name', border: border),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _unit,
              isExpanded: true,
              decoration:
              const InputDecoration(labelText: 'Unit', border: border),
              items: [
                for (final u in units)
                  DropdownMenuItem(value: u, child: Text(u)),
              ],
              onChanged: (v) => setState(() => _unit = v ?? _unit),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Current Stock', border: border),
                    validator: _numberValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _min,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Min Stock', border: border),
                    validator: _numberValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cost,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'Cost per $_unit', border: border),
              validator: _numberValidator,
            ),
          ],
        ),
      ),
    );
  }
}