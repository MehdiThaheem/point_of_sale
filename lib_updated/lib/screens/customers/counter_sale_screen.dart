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

// Shared palette so this screen and QuickSaleScreen look like one
// consistent product, not two different mockups stitched together.
class _Palette {
  static const navy = Color(0xFF0B1F3A);
  static const blue = Color(0xFF2F5FDE);
  static const green = Color(0xFF12A150);
  static const amber = Color(0xFFE3A008);
  static const bg = Color(0xFFF4F6FA);
  static const cardBorder = Color(0xFFE7EAF0);
}

// POS-style quick sale: search/tap products to build up the current
// order on the right, then Save.
class CounterSaleScreen extends StatefulWidget {
  const CounterSaleScreen({super.key});

  @override
  State<CounterSaleScreen> createState() => _CounterSaleScreenState();
}

class _CounterSaleScreenState extends State<CounterSaleScreen> {
  final SaleService _saleService = SaleService();
  final CustomerService _customerService = CustomerService();
  final ProductService _productService = ProductService();
  final QuotationService _quotationService = QuotationService();

  final List<SaleItem> _cart = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _poController = TextEditingController();
  final TextEditingController _discountController =
  TextEditingController(text: '0');
  final TextEditingController _paidController =
  TextEditingController(text: '0');
  bool _discountIsPercent = false;
  String _paymentMethod = 'Cash';
  Customer? _selectedCustomer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saleService.streamNextInvoiceNumber().first.then((next) {
      if (mounted) _invoiceController.text = next.toString();
    });
  }

  double get _total => _cart.fold(0, (sum, item) => sum + item.subtotal);

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
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        customerName: _selectedCustomer?.name ?? 'Walk-in',
        poNumber: _poController.text.trim(),
        items: _cart,
        totalAmount: _total,
        discount: _discount,
        paidAmount: _paid,
        paymentMethod: _paymentMethod,
      );
      await _saleService.addSale(sale);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: _Palette.green,
            content: Text('Sale #$invoiceNumber saved successfully.'),
          ),
        );
        setState(() {
          _cart.clear();
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryBar(),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 900;
                final productPanel = _buildProductPanel();
                final orderPanel = _buildOrderPanel();

                if (stacked) {
                  return Column(
                    children: [
                      SizedBox(height: 420, child: productPanel),
                      const SizedBox(height: 16),
                      orderPanel,
                    ],
                  );
                }

                return SizedBox(
                  height: 640,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: productPanel),
                      const SizedBox(width: 16),
                      SizedBox(width: 360, child: orderPanel),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildRecentSales(),
          ],
        ),
      ),
    );
  }

  // ================= TOP SUMMARY BAR =================
  // Every field width is a FRACTION of the available card width (never a
  // fixed pixel count), so this can never overflow — on a narrow phone
  // fields simply stack two-per-row instead of squeezing sideways.

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1B2B4B), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          // Roughly how many "slots" fit per row at this width.
          final cols = w > 1000
              ? 8
              : w > 760
              ? 5
              : w > 480
              ? 3
              : 2;
          final gap = 14.0;
          final slotWidth = (w - gap * (cols - 1)) / cols;

          Widget slot(Widget child, {int span = 1}) {
            final width = slotWidth * span + gap * (span - 1);
            return SizedBox(width: width, child: child);
          }

          return Wrap(
            spacing: gap,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              slot(_summaryField(
                'Invoice #',
                TextField(
                  controller: _invoiceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: _tightDecoration(),
                ),
              )),
              slot(_summaryField(
                'Date',
                Text(
                  '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              )),
              slot(
                _summaryField(
                  'Customer',
                  StreamBuilder<List<Customer>>(
                    stream: _customerService.streamCustomers(),
                    builder: (context, snapshot) {
                      final customers = snapshot.data ?? [];
                      return DropdownButtonFormField<Customer?>(
                        value: _selectedCustomer,
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
                span: 2,
              ),
              slot(_summaryField(
                'PO #',
                TextField(
                    controller: _poController, decoration: _tightDecoration()),
              )),
              slot(_summaryField(
                  'Total',
                  Text(_total.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold)))),
              slot(
                _summaryField(
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
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 40,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: _discountIsPercent,
                                onChanged: (v) => setState(
                                        () => _discountIsPercent = v ?? false),
                              ),
                            ),
                            const Text('%', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                span: 2,
              ),
              slot(_summaryField(
                  'Net',
                  Text(_net.toStringAsFixed(0),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: _Palette.blue)))),
              slot(_summaryField(
                'Paid',
                TextField(
                  controller: _paidController,
                  keyboardType: TextInputType.number,
                  decoration: _tightDecoration(),
                  onChanged: (_) => setState(() {}),
                ),
              )),
              slot(
                _summaryField(
                  'Payment',
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    isExpanded: true,
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
                span: 2,
              ),
              slot(
                SizedBox(
                  height: 48,
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
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('SAVE',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                span: 2,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _tightDecoration() {
    return InputDecoration(
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: _Palette.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ================= PRODUCT PANEL =================

  Widget _buildProductPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1B2B4B), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined, color: _Palette.blue, size: 20),
              const SizedBox(width: 8),
              const Text('Products',
                  style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search Product...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: _Palette.bg,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
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
                    childAspectRatio: 1.25,
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
                          color: _Palette.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _Palette.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: _Palette.blue.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.inventory_2_outlined,
                                  color: _Palette.blue, size: 18),
                            ),
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
                              style: TextStyle(
                                  color: _Palette.blue,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                                'Stock: ${product.currentStock.toStringAsFixed(0)}',
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Palette.navy, Color(0xFF122A4E)],
        ),
        borderRadius: BorderRadius.circular(14),
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
                  backgroundColor: _Palette.amber,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('SAVE QUOTATION',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
              color: highlight ? _Palette.amber : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: highlight ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  // ================= RECENT SALES (visible right here too) =================

  Widget _buildRecentSales() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1B2B4B), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: _Palette.blue, size: 20),
              const SizedBox(width: 8),
              const Text('Recent Sales',
                  style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 10),
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
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
        ],
      ),
    );
  }
}