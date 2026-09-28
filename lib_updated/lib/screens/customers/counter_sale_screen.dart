import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/quotation.dart';
import '../../models/sales.dart';
import '../../services/customer_service.dart';
import '../../services/product_service.dart';
import '../../services/quotation_service.dart';
import '../../services/sale_service.dart';
import '../../services/user_service.dart';

// POS-style quick sale: search/tap products to build up the current
// order on the right, then Save. Matches the "Counter Sale" screen from
// the reference design — same fields, same panel layout.
class CounterSaleScreen extends StatefulWidget {
  const CounterSaleScreen({super.key});

  @override
  State<CounterSaleScreen> createState() => _CounterSaleScreenState();
}

class _CounterSaleScreenState extends State<CounterSaleScreen> {
  final SaleService _saleService = SaleService();
  final UserService _userService = UserService();
  final CustomerService _customerService = CustomerService();
  final ProductService _productService = ProductService();
  final QuotationService _quotationService = QuotationService();

  final List<SaleItem> _cart = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _poController = TextEditingController();
  final TextEditingController _discountController =
  TextEditingController(text: '0');
  final TextEditingController _paidController =
  TextEditingController(text: '0');
  // Invoice # is editable — we prefill it with the suggested next number
  // (via the summary bar's StreamBuilder) but the user can overwrite it.
  final TextEditingController _invoiceController = TextEditingController();
  bool _invoicePrefilled = false;
  bool _discountIsPercent = false;
  String _paymentMethod = 'Cash';
  Customer? _selectedCustomer;
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _poController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _invoiceController.dispose();
    super.dispose();
  }

  double get _total => _cart.fold(0, (sum, item) => sum + item.subtotal);

  // See the identical helper in quick_sale_screen.dart for why this
  // exists — it attributes the sale to whoever is logged in, for the
  // Invoices Report's Cashier column.
  Future<String> _currentUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    try {
      final doc = await _userService.getUserProfile(user.uid);
      final name = doc.data()?['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {
      // Fall through to the email-based fallback below.
    }
    return user.email?.split('@').first ?? '';
  }

  double get _discount {
    final raw = double.tryParse(_discountController.text.trim()) ?? 0;
    return _discountIsPercent ? _total * raw / 100 : raw;
  }

  double get _net => (_total - _discount).clamp(0, double.infinity);
  double get _paid => double.tryParse(_paidController.text.trim()) ?? 0;

  void _addToCart(Product product) {
    setState(() {
      final existingIndex =
      _cart.indexWhere((i) => i.productId == product.id);
      if (existingIndex >= 0) {
        final existing = _cart[existingIndex];
        _cart[existingIndex] = SaleItem(
          productId: existing.productId,
          productName: existing.productName,
          quantity: existing.quantity + 1,
          unitPrice: existing.unitPrice,
        );
      } else {
        _cart.add(SaleItem(
          productId: product.id,
          productName: product.name,
          quantity: 1,
          unitPrice: product.salePrice,
        ));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() => _cart.removeAt(index));
  }

  void _updateQty(int index, double qty) {
    if (qty <= 0) {
      _removeFromCart(index);
      return;
    }
    setState(() {
      final item = _cart[index];
      _cart[index] = SaleItem(
        productId: item.productId,
        productName: item.productName,
        quantity: qty,
        unitPrice: item.unitPrice,
      );
    });
  }

  Future<void> _holdQuotation() async {
    if (_cart.isEmpty) return;
    final quotation = Quotation(
      id: '',
      customerId: _selectedCustomer?.id ?? '',
      customerName: _selectedCustomer?.name ?? 'Walk-in',
      poNumber: _poController.text.trim(),
      items: List.from(_cart),
      discount: double.tryParse(_discountController.text.trim()) ?? 0,
      discountIsPercent: _discountIsPercent,
    );

    try {
      await _quotationService.addQuotation(quotation);
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _poController.clear();
        _discountController.text = '0';
        _selectedCustomer = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved as quotation.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save quotation: $e')),
        );
      }
    }
  }

  Future<void> _resumeQuotation(Quotation quotation) async {
    Customer? matchedCustomer;
    if (quotation.customerId.isNotEmpty) {
      final customers = await _customerService.streamCustomers().first;
      final match =
      customers.where((c) => c.id == quotation.customerId).toList();
      if (match.isNotEmpty) matchedCustomer = match.first;
    }

    setState(() {
      _selectedCustomer = matchedCustomer;
      _poController.text = quotation.poNumber;
      _discountController.text = quotation.discount.toStringAsFixed(0);
      _discountIsPercent = quotation.discountIsPercent;
      _cart
        ..clear()
        ..addAll(quotation.items);
    });
    await _quotationService.deleteQuotation(quotation.id);
    if (mounted) Navigator.pop(context);
  }

  void _showQuotationsList() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Held Quotations'),
        content: SizedBox(
          width: 360,
          child: StreamBuilder<List<Quotation>>(
            stream: _quotationService.streamQuotations(),
            builder: (context, snapshot) {
              final held = snapshot.data ?? [];
              if (held.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Nothing on hold.',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              return SizedBox(
                height: 300,
                child: ListView(
                  shrinkWrap: true,
                  children: held.map((quotation) {
                    return ListTile(
                      title: Text(quotation.customerName),
                      subtitle: Text(
                          '${quotation.items.length} item(s) · Rs ${quotation.total.toStringAsFixed(0)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _resumeQuotation(quotation),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product.')),
      );
      return;
    }

    final enteredInvoice = int.tryParse(_invoiceController.text.trim());
    if (enteredInvoice == null || enteredInvoice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid invoice number.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final cashierName = await _currentUserName();
      final sale = Sale(
        id: '',
        invoiceNumber: enteredInvoice,
        customerId: _selectedCustomer?.id ?? '',
        customerName: _selectedCustomer?.name ?? 'Walk-in',
        poNumber: _poController.text.trim(),
        items: _cart,
        totalAmount: _total,
        discount: _discount,
        paidAmount: _paid,
        paymentMethod: _paymentMethod,
        cashierName: cashierName,
      );
      await _saleService.addSale(sale);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale #$enteredInvoice saved.')),
        );
        setState(() {
          _cart.clear();
          _poController.clear();
          _discountController.text = '0';
          _paidController.text = '0';
          _selectedCustomer = null;
          _invoiceController.clear();
          _invoicePrefilled = false;
        });
      }
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
    // NOTE: an earlier version of this wrapped everything in
    // IntrinsicHeight to fix a keyboard-overflow bug, but IntrinsicHeight
    // can't measure a LayoutBuilder (its size depends on the constraints
    // it's given, not something intrinsic sizing can compute), so the
    // whole screen failed to render. This version fixes the original
    // overflow a different way: on phone-width screens there's no
    // Expanded at all, so the whole screen just scrolls as one Column and
    // nothing can ever overflow, keyboard or not. Desktop/tablet keeps
    // the original side-by-side layout untouched.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 900;
          final productPanel = _buildProductPanel();
          final orderPanel = _buildOrderPanel();

          if (stacked) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryBar(),
                  const SizedBox(height: 16),
                  SizedBox(height: 400, child: productPanel),
                  const SizedBox(height: 16),
                  orderPanel,
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryBar(),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: productPanel),
                    const SizedBox(width: 16),
                    SizedBox(width: 360, child: orderPanel),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ================= TOP SUMMARY BAR =================

  Widget _buildSummaryBar() {
    return StreamBuilder<int>(
      stream: _saleService.streamNextInvoiceNumber(),
      builder: (context, invoiceSnapshot) {
        // Only auto-fill the suggested number the first time it arrives —
        // after that it's fully in the user's hands.
        if (!_invoicePrefilled && invoiceSnapshot.hasData) {
          _invoicePrefilled = true;
          _invoiceController.text = '${invoiceSnapshot.data}';
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 8)
            ],
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 100,
                child: _summaryField(
                  'Invoice #',
                  TextField(
                    controller: _invoiceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: _tightDecoration(),
                  ),
                ),
              ),
              _summaryField(
                  'Date',
                  Text(
                    '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
                  )),
              SizedBox(
                width: 220,
                child: _summaryField(
                  'Customer',
                  StreamBuilder<List<Customer>>(
                    stream: _customerService.streamCustomers(),
                    builder: (context, snapshot) {
                      final customers = snapshot.data ?? [];
                      return DropdownButtonFormField<Customer?>(
                        value: customers
                            .any((c) => c.id == _selectedCustomer?.id)
                            ? _selectedCustomer
                            : null,
                        isExpanded: true,
                        decoration: _tightDecoration(),
                        hint: const Text('Walk-in'),
                        items: [
                          const DropdownMenuItem<Customer?>(
                            value: null,
                            child: Text('Walk-in'),
                          ),
                          ...customers.map((c) => DropdownMenuItem(
                              value: c, child: Text(c.name))),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedCustomer = v),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: _summaryField(
                  'PO #',
                  TextField(
                      controller: _poController,
                      decoration: _tightDecoration()),
                ),
              ),
              _summaryField(
                  'Total',
                  Text(_total.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(
                width: 130,
                child: _summaryField(
                  'Discount',
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          decoration: _tightDecoration(),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Checkbox(
                        value: _discountIsPercent,
                        onChanged: (v) => setState(
                                () => _discountIsPercent = v ?? false),
                      ),
                      const Text('%'),
                    ],
                  ),
                ),
              ),
              _summaryField(
                  'Net',
                  Text(_net.toStringAsFixed(0),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3159C9)))),
              SizedBox(
                width: 100,
                child: _summaryField(
                  'Paid',
                  TextField(
                    controller: _paidController,
                    keyboardType: TextInputType.number,
                    decoration: _tightDecoration(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              SizedBox(
                width: 130,
                child: _summaryField(
                  'Payment',
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: _tightDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'Card', child: Text('Card')),
                      DropdownMenuItem(
                          value: 'Bank Transfer',
                          child: Text('Bank Transfer')),
                    ],
                    onChanged: (v) =>
                        setState(() => _paymentMethod = v ?? 'Cash'),
                  ),
                ),
              ),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A673),
                    foregroundColor: Colors.white,
                  ),
                  child: _saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('SAVE'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryField(String label, Widget child) {
    return SizedBox(
      width: 90,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  InputDecoration _tightDecoration() {
    return const InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      border: OutlineInputBorder(),
    );
  }

  // ================= PRODUCT PANEL =================

  Widget _buildProductPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search Product...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _productService.streamProducts(),
              builder: (context, snapshot) {
                var products = snapshot.data ?? [];
                final query = _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  products = products
                      .where(
                          (p) => p.name.toLowerCase().contains(query))
                      .toList();
                }
                if (products.isEmpty) {
                  return const Center(
                    child: Text('No products found',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return GridView.builder(
                  gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 170,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return InkWell(
                      onTap: () => _addToCart(product),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                color: Colors.blueGrey.shade300, size: 28),
                            const Spacer(),
                            Text(product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              'Rs ${product.salePrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Color(0xFF3159C9),
                                  fontWeight: FontWeight.bold),
                            ),
                            Text('Stock: ${product.currentStock.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= CURRENT ORDER PANEL =================

  Widget _buildOrderPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF03213D),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Order',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _showQuotationsList,
                  icon: const Icon(Icons.list_alt,
                      size: 16, color: Colors.white70),
                  label: const Text('Quotations',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 20),
            if (_cart.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text('No items yet — tap a product to add it.',
                      style: TextStyle(color: Colors.white60)),
                ),
              )
            else
              ..._cart.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(item.productName,
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(
                        width: 46,
                        child: TextFormField(
                          initialValue: item.quantity.toStringAsFixed(0),
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            enabledBorder: UnderlineInputBorder(
                                borderSide:
                                BorderSide(color: Colors.white38)),
                          ),
                          onFieldSubmitted: (v) => _updateQty(
                              index, double.tryParse(v) ?? item.quantity),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          item.subtotal.toStringAsFixed(0),
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.redAccent, size: 18),
                        onPressed: () => _removeFromCart(index),
                      ),
                    ],
                  ),
                );
              }),
            const Divider(color: Colors.white24, height: 24),
            _orderTotalRow('Total', _total),
            _orderTotalRow('Discount', _discount),
            _orderTotalRow('Net', _net, highlight: true),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: _cart.isEmpty ? null : _holdQuotation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8A900),
                  foregroundColor: Colors.white,
                ),
                child: const Text('SAVE QUOTATION'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderTotalRow(String label, double value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: highlight ? Colors.white : Colors.white70)),
          Text(
            'Rs ${value.toStringAsFixed(0)}',
            style: TextStyle(
              color: highlight ? const Color(0xFFE8A900) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: highlight ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}