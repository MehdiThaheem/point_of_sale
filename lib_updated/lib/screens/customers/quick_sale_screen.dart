import 'package:cloud_firestore/cloud_firestore.dart';
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

// The simpler, form-based Sale screen: pick or type a customer, add
// products one row at a time, see the running total on the right.
// Matches the "Sale" tab from the reference design.
class QuickSaleScreen extends StatefulWidget {
  const QuickSaleScreen({super.key});

  @override
  State<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends State<QuickSaleScreen> {
  final SaleService _saleService = SaleService();
  final UserService _userService = UserService();  final CustomerService _customerService = CustomerService();
  final ProductService _productService = ProductService();
  final QuotationService _quotationService = QuotationService();

  final TextEditingController _customerNameController =
  TextEditingController();
  final TextEditingController _poController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _qtyController =
  TextEditingController(text: '1');
  final TextEditingController _discountController =
  TextEditingController(text: '0');
  final TextEditingController _paidController =
  TextEditingController(text: '0');
  // Invoice # is editable — we prefill it with the suggested next number
  // (via _prefillInvoiceNumber) but the user can overwrite it by hand.
  final TextEditingController _invoiceController = TextEditingController();
  bool _invoicePrefilled = false;

  Customer? _selectedCustomer;
  Product? _selectedProduct;
  bool _discountIsPercent = false;
  String _paymentMethod = 'Cash';
  final List<SaleItem> _items = [];
  bool _saving = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _poController.dispose();
    _priceController.dispose();
    _qtyController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _invoiceController.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0, (sum, i) => sum + i.subtotal);

  // Looks up the currently logged-in user's display name for the
  // "Cashier" column on the Invoices Report. Falls back to the part of
  // their email before the @ if their profile has no name set, and to
  // an empty string if nobody is signed in (shouldn't normally happen
  // here, but this screen shouldn't crash over a report column).
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
  double get _remaining => _net - _paid;

  void _addRow() {
    if (_selectedProduct == null) return;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ??
        _selectedProduct!.salePrice;
    if (qty <= 0) return;

    setState(() {
      _items.add(SaleItem(
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        quantity: qty,
        unitPrice: price,
      ));
      _qtyController.text = '1';
    });
  }

  Future<void> _holdQuotation() async {
    if (_items.isEmpty) return;
    final quotation = Quotation(
      id: '',
      customerId: _selectedCustomer?.id ?? '',
      customerName: _customerNameController.text.trim().isEmpty
          ? (_selectedCustomer?.name ?? 'Walk-in')
          : _customerNameController.text.trim(),
      poNumber: _poController.text.trim(),
      items: List.from(_items),
      discount: double.tryParse(_discountController.text.trim()) ?? 0,
      discountIsPercent: _discountIsPercent,
    );

    try {
      await _quotationService.addQuotation(quotation);
      if (!mounted) return;
      setState(() {
        _items.clear();
        _customerNameController.clear();
        _poController.clear();
        _discountController.text = '0';
        _selectedCustomer = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Held for later.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not hold: $e')),
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
      _customerNameController.text = quotation.customerName;
      _poController.text = quotation.poNumber;
      _discountController.text = quotation.discount.toStringAsFixed(0);
      _discountIsPercent = quotation.discountIsPercent;
      _items
        ..clear()
        ..addAll(quotation.items);
    });
    // Loaded into the form — remove it from the hold list so it isn't
    // resumed twice.
    await _quotationService.deleteQuotation(quotation.id);
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
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
        customerName: _selectedCustomer?.name ??
            (_customerNameController.text.trim().isEmpty
                ? 'Walk-in'
                : _customerNameController.text.trim()),
        poNumber: _poController.text.trim(),
        items: _items,
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
          _items.clear();
          _customerNameController.clear();
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 950;
          final holdPanel = _buildHoldPanel();
          final salePanel = _buildSaleForm();
          final summaryPanel = StreamBuilder<int>(
            stream: _saleService.streamNextInvoiceNumber(),
            builder: (context, snapshot) {
              // Only auto-fill the suggested number the first time it
              // arrives, and only if the user hasn't already typed one —
              // after that it's fully in the user's hands.
              if (!_invoicePrefilled && snapshot.hasData) {
                _invoicePrefilled = true;
                _invoiceController.text = '${snapshot.data}';
              }
              return _buildSummaryPanel();
            },
          );

          if (stacked) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  holdPanel,
                  const SizedBox(height: 16),
                  salePanel,
                  const SizedBox(height: 16),
                  summaryPanel,
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 220, child: holdPanel),
                const SizedBox(width: 16),
                Expanded(child: salePanel),
                const SizedBox(width: 16),
                SizedBox(width: 300, child: summaryPanel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _panelShell(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ================= HOLD / QUOTATIONS PANEL =================

  Widget _buildHoldPanel() {
    return _panelShell(
      'Quotations/Hold',
      StreamBuilder<List<Quotation>>(
        stream: _quotationService.streamQuotations(),
        builder: (context, snapshot) {
          final held = snapshot.data ?? [];
          if (held.isEmpty) {
            return const Text('Nothing on hold.',
                style: TextStyle(color: Colors.grey, fontSize: 12));
          }
          return Column(
            children: held.map((quotation) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(quotation.customerName),
                subtitle: Text(
                    '${quotation.items.length} item(s) · Rs ${quotation.total.toStringAsFixed(0)}'),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _resumeQuotation(quotation),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ================= SALE FORM PANEL =================

  Widget _buildSaleForm() {
    return _panelShell(
      'Sale',
      StreamBuilder<List<Customer>>(
        stream: _customerService.streamCustomers(),
        builder: (context, customerSnapshot) {
          final customers = customerSnapshot.data ?? [];

          return StreamBuilder<List<Product>>(
            stream: _productService.streamProducts(),
            builder: (context, productSnapshot) {
              final products = productSnapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _field(
                          'Customer Name',
                          TextField(
                            controller: _customerNameController,
                            decoration: _decoration(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          'Select Party',
                          DropdownButtonFormField<Customer?>(
                            value: customers.any(
                                    (c) => c.id == _selectedCustomer?.id)
                                ? _selectedCustomer
                                : null,
                            isExpanded: true,
                            decoration: _decoration(),
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          'Previous Balance',
                          TextField(
                            enabled: false,
                            controller: TextEditingController(
                                text: (_selectedCustomer?.totalReceivable ??
                                    0)
                                    .toStringAsFixed(0)),
                            decoration: _decoration(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _field(
                          'Product',
                          DropdownButtonFormField<Product>(
                            value: products
                                .any((p) => p.id == _selectedProduct?.id)
                                ? _selectedProduct
                                : null,
                            isExpanded: true,
                            decoration: _decoration(hint: 'Select Product'),
                            items: products
                                .map((p) => DropdownMenuItem(
                                value: p, child: Text(p.name)))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedProduct = v;
                                _priceController.text =
                                    v?.salePrice.toStringAsFixed(0) ?? '';
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          'Price',
                          TextField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              decoration: _decoration()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          'Qty',
                          TextField(
                              controller: _qtyController,
                              keyboardType: TextInputType.number,
                              decoration: _decoration()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _addRow,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3159C9),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildItemsTable(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildItemsTable() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade200),
      columnWidths: const {
        0: FixedColumnWidth(30),
        4: FixedColumnWidth(60),
        5: FixedColumnWidth(36),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: const [
            _Cell('#', bold: true),
            _Cell('Name', bold: true),
            _Cell('Price', bold: true),
            _Cell('Qty', bold: true),
            _Cell('Total', bold: true),
            _Cell('X', bold: true),
          ],
        ),
        ..._items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return TableRow(children: [
            _Cell('${i + 1}'),
            _Cell(item.productName),
            _Cell(item.unitPrice.toStringAsFixed(0)),
            _Cell(item.quantity.toStringAsFixed(0)),
            _Cell(item.subtotal.toStringAsFixed(0)),
            Padding(
              padding: const EdgeInsets.all(4),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close,
                    size: 16, color: Colors.redAccent),
                onPressed: () => setState(() => _items.removeAt(i)),
              ),
            ),
          ]);
        }),
      ],
    );
  }

  Widget _field(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _decoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: const OutlineInputBorder(),
    );
  }

  // ================= SUMMARY PANEL =================

  Widget _buildSummaryPanel() {
    return _panelShell(
      'Summary',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('PO #',
              TextField(controller: _poController, decoration: _decoration())),
          const SizedBox(height: 12),
          _field(
              'Date',
              Text(
                  '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}')),
          const SizedBox(height: 12),
          _field(
              'Invoice No',
              TextField(
                controller: _invoiceController,
                keyboardType: TextInputType.number,
                decoration: _decoration(),
              )),
          const SizedBox(height: 12),
          _field('Total', Text(_total.toStringAsFixed(0))),
          const SizedBox(height: 12),
          _field(
            'Discount',
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    decoration: _decoration(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Checkbox(
                  value: _discountIsPercent,
                  onChanged: (v) =>
                      setState(() => _discountIsPercent = v ?? false),
                ),
                const Text('%'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _field(
              'Net',
              Text(_net.toStringAsFixed(0),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3159C9)))),
          const SizedBox(height: 12),
          _field(
            'Paid',
            TextField(
              controller: _paidController,
              keyboardType: TextInputType.number,
              decoration: _decoration(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          _field(
              'Remaining',
              Text(_remaining.toStringAsFixed(0),
                  style: TextStyle(
                      color: _remaining > 0 ? Colors.red : Colors.grey,
                      fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          _field(
            'Payment',
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: _decoration(),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'Card', child: Text('Card')),
                DropdownMenuItem(
                    value: 'Bank Transfer', child: Text('Bank Transfer')),
              ],
              onChanged: (v) => setState(() => _paymentMethod = v ?? 'Cash'),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
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
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _items.isEmpty ? null : _holdQuotation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8A900),
                foregroundColor: Colors.white,
              ),
              child: const Text('Quotation/Hold'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool bold;
  const _Cell(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text,
          style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13)),
    );
  }
}