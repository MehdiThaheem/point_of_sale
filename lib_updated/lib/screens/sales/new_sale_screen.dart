import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/sales.dart';
import '../../services/branch_service.dart';
import '../../services/customer_service.dart';
import '../../services/product_service.dart';
import '../../services/sale_service.dart';
import '../../utils/branch_filter.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final SaleService _saleService = SaleService();
  final CustomerService _customerService = CustomerService();
  final ProductService _productService = ProductService();
  final BranchService _branchService = BranchService();

  Customer? _selectedCustomer;
  String? _selectedBranchId;
  final List<SaleItem> _items = [];
  final TextEditingController _paidController =
  TextEditingController(text: '0');
  bool _saving = false;
  bool _branchInitialized = false;

  double get _total => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _paid => double.tryParse(_paidController.text.trim()) ?? 0;
  double get _due => _total - _paid;

  void _addItemDialog(List<Product> products) {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a product first.')),
      );
      return;
    }

    Product selectedProduct = products.first;
    final qtyController = TextEditingController(text: '1');
    final priceController =
    TextEditingController(text: selectedProduct.salePrice.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Item'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width < 460
                ? MediaQuery.of(context).size.width * 0.85
                : 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Product>(
                  value: selectedProduct,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: products
                      .map((p) => DropdownMenuItem(
                      value: p,
                      child:
                      Text('${p.name} (Stock: ${p.currentStock})')))
                      .toList(),
                  onChanged: (v) {
                    setDialogState(() {
                      selectedProduct = v!;
                      priceController.text = v.salePrice.toString();
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Unit Price'),
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
                final qty = double.tryParse(qtyController.text.trim()) ?? 0;
                final price =
                    double.tryParse(priceController.text.trim()) ?? 0;
                if (qty <= 0) return;

                setState(() {
                  _items.add(SaleItem(
                    productId: selectedProduct.id,
                    productName: selectedProduct.name,
                    quantity: qty,
                    unitPrice: price,
                  ));
                });

                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(List<Branch> branches) async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer.')),
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

    final sale = Sale(
      id: '',
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.name,
      items: _items,
      totalAmount: _total,
      paidAmount: _paid,
      branchId: _selectedBranchId ?? '',
      branchName: branchName,
    );

    try {
      await _saleService.addSale(sale);
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
      appBar: AppBar(title: const Text('New Sale')),
      body: StreamBuilder<List<Branch>>(
        stream: _branchService.streamBranches(),
        builder: (context, branchSnapshot) {
          final branches = branchSnapshot.data ?? [];

          if (!_branchInitialized && selectedBranchId.value != null) {
            _selectedBranchId = selectedBranchId.value;
            _branchInitialized = true;
          }

          return StreamBuilder<List<Customer>>(
            stream: _customerService.streamCustomers(),
            builder: (context, customerSnapshot) {
              final customers = customerSnapshot.data ?? [];

              return StreamBuilder<List<Product>>(
                stream: _productService.streamProducts(),
                builder: (context, productSnapshot) {
                  final products = productSnapshot.data ?? [];

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
                        DropdownButtonFormField<Customer>(
                          value: customers.any(
                                  (c) => c.id == _selectedCustomer?.id)
                              ? _selectedCustomer
                              : null,
                          decoration:
                          const InputDecoration(labelText: 'Customer'),
                          items: customers
                              .map((c) => DropdownMenuItem(
                              value: c, child: Text(c.name)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCustomer = v),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Text(
                              'Items',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _addItemDialog(products),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Item'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              'No items added yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          Card(
                            child: Column(
                              children: _items.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                return ListTile(
                                  title: Text(item.productName),
                                  subtitle: Text(
                                      '${item.quantity} x ${item.unitPrice} = ${item.subtotal.toStringAsFixed(0)}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent),
                                    onPressed: () {
                                      setState(() => _items.removeAt(index));
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
                          decoration:
                          const InputDecoration(labelText: 'Paid Amount'),
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
                            onPressed:
                            _saving ? null : () => _submit(branches),
                            child: _saving
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                                : const Text('Save Sale'),
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