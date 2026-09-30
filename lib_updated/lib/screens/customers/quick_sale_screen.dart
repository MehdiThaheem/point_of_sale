import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/quotation.dart';
import '../../models/sales.dart';
import '../../services/customer_service.dart';
import '../../services/product_service.dart';
import '../../services/quotation_service.dart';
import '../../services/sale_service.dart';
import '../../utils/branch_context.dart';

class _Palette {
  static const navy = Color(0xFF0B1F3A);
  static const blue = Color(0xFF2F5FDE);
  static const green = Color(0xFF12A150);
  static const amber = Color(0xFFE3A008);
  static const bg = Color(0xFFF4F6FA);
  static const cardBorder = Color(0xFFE7EAF0);
}

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
  final CustomerService _customerService = CustomerService();
  final ProductService _productService = ProductService();
  final QuotationService _quotationService = QuotationService();

  final TextEditingController _customerNameController =
  TextEditingController();
  final TextEditingController _poController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _qtyController =
  TextEditingController(text: '1');
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _discountController =
  TextEditingController(text: '0');
  final TextEditingController _paidController =
  TextEditingController(text: '0');

  Customer? _selectedCustomer;
  Product? _selectedProduct;
  bool _discountIsPercent = false;
  String _paymentMethod = 'Cash';
  final List<SaleItem> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Just a starting suggestion — the field stays fully editable so
    // staff can type their own numbering instead.
    _saleService.streamNextInvoiceNumber().first.then((next) {
      if (mounted) _invoiceController.text = next.toString();
    });
  }

  double get _total => _items.fold(0, (sum, i) => sum + i.subtotal);

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

    final invoiceNumber = int.tryParse(_invoiceController.text.trim());
    if (invoiceNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid invoice number.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final branch = await resolveCurrentBranch();
      final sale = Sale(
        id: '',
        invoiceNumber: invoiceNumber,
        branchId: branch.id,
        branchName: branch.name,
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
      );
      await _saleService.addSale(sale);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale #$invoiceNumber saved.')),
        );
        setState(() {
          _items.clear();
          _customerNameController.clear();
          _poController.clear();
          _discountController.text = '0';
          _paidController.text = '0';
          _selectedCustomer = null;
        });
        _saleService.streamNextInvoiceNumber().first.then((next) {
          if (mounted) _invoiceController.text = next.toString();
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
    return Container(
      color: _Palette.bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 950;
            final holdPanel = _buildHoldPanel();
            final salePanel = _buildSaleForm();
            final summaryPanel = _buildSummaryPanel();
            final recentSales = _buildRecentSales();

            if (stacked) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    holdPanel,
                    const SizedBox(height: 16),
                    salePanel,
                    const SizedBox(height: 16),
                    summaryPanel,
                    const SizedBox(height: 16),
                    recentSales,
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  IntrinsicHeight(
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
                  ),
                  const SizedBox(height: 16),
                  recentSales,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _panelShell(String title, Widget child, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1B2B4B), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: _Palette.blue, size: 20),
                const SizedBox(width: 8),
              ],
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
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
      icon: Icons.list_alt,
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
      icon: Icons.point_of_sale_outlined,
      StreamBuilder<List<Customer>>(
        stream: _customerService.streamCustomers(),
        builder: (context, customerSnapshot) {
          final customers = customerSnapshot.data ?? [];

          return StreamBuilder<List<Product>>(
            stream: _productService.streamProducts(),
            builder: (context, productSnapshot) {
              final products = productSnapshot.data ?? [];

              return LayoutBuilder(
                builder: (context, formConstraints) {
                  final narrow = formConstraints.maxWidth < 560;

                  final customerNameField = _field(
                    'Customer Name',
                    TextField(
                      controller: _customerNameController,
                      decoration: _decoration(),
                    ),
                  );
                  final selectPartyField = _field(
                    'Select Party',
                    DropdownButtonFormField<Customer?>(
                      value: _selectedCustomer,
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
                  );
                  final previousBalanceField = _field(
                    'Previous Balance',
                    TextField(
                      enabled: false,
                      controller: TextEditingController(
                          text: (_selectedCustomer?.totalReceivable ?? 0)
                              .toStringAsFixed(0)),
                      decoration: _decoration(),
                    ),
                  );

                  final topRow = narrow
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      customerNameField,
                      const SizedBox(height: 12),
                      selectPartyField,
                      const SizedBox(height: 12),
                      previousBalanceField,
                    ],
                  )
                      : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: customerNameField),
                      const SizedBox(width: 12),
                      Expanded(child: selectPartyField),
                      const SizedBox(width: 12),
                      Expanded(child: previousBalanceField),
                    ],
                  );

                  final productField = _field(
                    'Product',
                    DropdownButtonFormField<Product>(
                      value: _selectedProduct,
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
                  );
                  final priceField = _field(
                    'Price',
                    TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: _decoration()),
                  );
                  final qtyField = _field(
                    'Qty',
                    TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: _decoration()),
                  );
                  final addButton = SizedBox(
                    width: narrow ? double.infinity : 46,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _addRow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Palette.blue,
                        padding: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: narrow
                          ? const Text('ADD ITEM',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))
                          : const Icon(Icons.add, color: Colors.white),
                    ),
                  );

                  final productRow = narrow
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      productField,
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: priceField),
                          const SizedBox(width: 12),
                          Expanded(child: qtyField),
                        ],
                      ),
                      const SizedBox(height: 12),
                      addButton,
                    ],
                  )
                      : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: productField),
                      const SizedBox(width: 12),
                      Expanded(child: priceField),
                      const SizedBox(width: 12),
                      Expanded(child: qtyField),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: addButton,
                      ),
                    ],
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      topRow,
                      const SizedBox(height: 16),
                      productRow,
                      const SizedBox(height: 16),
                      _buildItemsTable(),
                    ],
                  );
                },
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
      icon: Icons.receipt_long_outlined,
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
                  decoration: _decoration())),
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
                backgroundColor: _Palette.green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _items.isEmpty ? null : _holdQuotation,
              style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.amber,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Quotation/Hold',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ================= RECENT SALES =================

  Widget _buildRecentSales() {
    return _panelShell(
      'Recent Sales',
      icon: Icons.history,
      StreamBuilder<List<Sale>>(
        stream: _saleService.streamSales(),
        builder: (context, snapshot) {
          final sales = (snapshot.data ?? []).take(6).toList();
          if (sales.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('No sales recorded yet.',
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return Column(
            children: sales.map((sale) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _Palette.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.receipt_long_outlined,
                          color: _Palette.green, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${sale.invoiceNumber} · ${sale.customerName}',
                            style:
                            const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${sale.items.length} item(s) · ${sale.paymentMethod}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Rs ${sale.netAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
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