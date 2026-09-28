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

class NewPurchaseScreen extends StatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  State<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends State<NewPurchaseScreen> {
  final PurchaseService _purchaseService = PurchaseService();
  final SupplierService _supplierService = SupplierService();
  final ProductService _productService = ProductService();
  final RawMaterialService _rawMaterialService = RawMaterialService();
  final BranchService _branchService = BranchService();

  Supplier? _selectedSupplier;
  String? _selectedBranchId;
  bool _branchInitialized = false;
  final List<PurchaseItem> _items = [];
  final TextEditingController _paidController =
  TextEditingController(text: '0');
  bool _saving = false;

  double get _total => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _paid => double.tryParse(_paidController.text.trim()) ?? 0;
  double get _due => _total - _paid;

  void _addItemDialog(List<Product> products, List<RawMaterial> rawMaterials) {
    String itemType = 'product';
    dynamic selected = products.isNotEmpty ? products.first : null;
    final qtyController = TextEditingController(text: '1');
    final costController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentList = itemType == 'product' ? products : rawMaterials;

          return AlertDialog(
            title: const Text('Add Item'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width < 460
                  ? MediaQuery.of(context).size.width * 0.85
                  : 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Product'),
                          selected: itemType == 'product',
                          onSelected: (_) => setDialogState(() {
                            itemType = 'product';
                            selected =
                            products.isNotEmpty ? products.first : null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Raw Material'),
                          selected: itemType == 'raw_material',
                          onSelected: (_) => setDialogState(() {
                            itemType = 'raw_material';
                            selected = rawMaterials.isNotEmpty
                                ? rawMaterials.first
                                : null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (currentList.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No items found in this category.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    DropdownButtonFormField(
                      value: selected,
                      decoration: const InputDecoration(labelText: 'Item'),
                      items: currentList.map((item) {
                        final name = item is Product
                            ? item.name
                            : (item as RawMaterial).name;
                        return DropdownMenuItem(value: item, child: Text(name));
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selected = v),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Unit Cost'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selected == null) return;
                  final qty = double.tryParse(qtyController.text.trim()) ?? 0;
                  final cost =
                      double.tryParse(costController.text.trim()) ?? 0;
                  if (qty <= 0) return;

                  final id = selected is Product
                      ? (selected as Product).id
                      : (selected as RawMaterial).id;
                  final name = selected is Product
                      ? (selected as Product).name
                      : (selected as RawMaterial).name;

                  setState(() {
                    _items.add(PurchaseItem(
                      itemType: itemType,
                      itemId: id,
                      itemName: name,
                      quantity: qty,
                      unitCost: cost,
                    ));
                  });

                  Navigator.pop(ctx);
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit(List<Branch> branches) async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a supplier.')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item.')),
      );
      return;
    }

    setState(() => _saving = true);

    final branchName = _selectedBranchId == null
        ? ''
        : branches.firstWhere((b) => b.id == _selectedBranchId).name;

    final purchase = Purchase(
      id: '',
      supplierId: _selectedSupplier!.id,
      supplierName: _selectedSupplier!.name,
      items: _items,
      totalAmount: _total,
      paidAmount: _paid,
      branchId: _selectedBranchId ?? '',
      branchName: branchName,
    );

    try {
      await _purchaseService.addPurchase(purchase);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase')),
      body: StreamBuilder<List<Branch>>(
        stream: _branchService.streamBranches(),
        builder: (context, branchSnapshot) {
          final branches = branchSnapshot.data ?? [];

          if (!_branchInitialized && selectedBranchId.value != null) {
            _selectedBranchId = selectedBranchId.value;
            _branchInitialized = true;
          }

          return StreamBuilder<List<Supplier>>(
            stream: _supplierService.streamSuppliers(),
            builder: (context, supplierSnapshot) {
              final suppliers = supplierSnapshot.data ?? [];

              return StreamBuilder<List<Product>>(
                stream: _productService.streamProducts(),
                builder: (context, productSnapshot) {
                  final products = productSnapshot.data ?? [];

                  return StreamBuilder<List<RawMaterial>>(
                    stream: _rawMaterialService.streamRawMaterials(),
                    builder: (context, rawSnapshot) {
                      final rawMaterials = rawSnapshot.data ?? [];

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedBranchId,
                              decoration:
                              const InputDecoration(labelText: 'Branch'),
                              items: branches
                                  .map((b) => DropdownMenuItem(
                                  value: b.id, child: Text(b.name)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedBranchId = v),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<Supplier>(
                              value: suppliers.any(
                                      (s) => s.id == _selectedSupplier?.id)
                                  ? _selectedSupplier
                                  : null,
                              decoration:
                              const InputDecoration(labelText: 'Supplier'),
                              items: suppliers
                                  .map((s) => DropdownMenuItem(
                                  value: s, child: Text(s.name)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedSupplier = v),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Text('Items',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () =>
                                      _addItemDialog(products, rawMaterials),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Item'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text('No items added yet.',
                                    style: TextStyle(color: Colors.grey)),
                              )
                            else
                              Card(
                                child: Column(
                                  children:
                                  _items.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    return ListTile(
                                      title: Text(item.itemName),
                                      subtitle: Text(
                                          '${item.itemType == 'raw_material' ? 'Raw Material' : 'Product'}  •  '
                                              '${item.quantity} x ${item.unitCost} = ${item.subtotal.toStringAsFixed(0)}'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.redAccent),
                                        onPressed: () {
                                          setState(
                                                  () => _items.removeAt(index));
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _paidController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Paid Amount'),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            _summaryRow('Total', _total),
                            _summaryRow('Paid', _paid),
                            _summaryRow('Due', _due, highlight: _due > 0),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _saving
                                    ? null
                                    : () => _submit(branches),
                                child: _saving
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                                    : const Text('Save Purchase'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}