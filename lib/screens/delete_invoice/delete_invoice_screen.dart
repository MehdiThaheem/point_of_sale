import 'package:flutter/material.dart';
import '../../models/sales.dart';
import '../../services/sale_service.dart';
import '../../widgets/confirm_dialog.dart';

class DeleteInvoiceScreen extends StatefulWidget {
  const DeleteInvoiceScreen({super.key});

  @override
  State<DeleteInvoiceScreen> createState() => _DeleteInvoiceScreenState();
}

class _DeleteInvoiceScreenState extends State<DeleteInvoiceScreen> {
  final SaleService _saleService = SaleService();
  final TextEditingController _invoiceController = TextEditingController();

  bool _searching = false;
  bool _deleting = false;
  bool _searched = false;
  Sale? _result;

  @override
  void dispose() {
    _invoiceController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final invoiceNumber = int.tryParse(_invoiceController.text.trim());
    if (invoiceNumber == null || invoiceNumber <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid invoice number.')),
      );
      return;
    }

    setState(() {
      _searching = true;
      _searched = false;
      _result = null;
    });

    try {
      final sale = await _saleService.findByInvoiceNumber(invoiceNumber);
      if (mounted) {
        setState(() {
          _result = sale;
          _searched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _delete() async {
    final sale = _result;
    if (sale == null) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Invoice #${sale.invoiceNumber}',
      message:
      'This permanently deletes the invoice, restores the stock it '
          'used, and reverses the customer\'s balance. This cannot be undone.',
    );
    if (!confirmed) return;

    setState(() => _deleting = true);
    try {
      await _saleService.deleteSale(sale);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice #${sale.invoiceNumber} deleted.')),
        );
        setState(() {
          _result = null;
          _searched = false;
          _invoiceController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete invoice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delete Invoice',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Search a sale by its invoice number to view and delete it.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x10000000), blurRadius: 10),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search Invoice',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 480;
                    final field = TextField(
                      controller: _invoiceController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: 'Enter Invoice No',
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                      ),
                    );
                    final button = SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _searching ? null : _search,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3159C9),
                          foregroundColor: Colors.white,
                          padding:
                          const EdgeInsets.symmetric(horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _searching
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                            : const Text('Search'),
                      ),
                    );

                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          field,
                          const SizedBox(height: 10),
                          button,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: field),
                        const SizedBox(width: 12),
                        button,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_searched) _buildResult(),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final sale = _result;

    if (sale == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x10000000), blurRadius: 10),
          ],
        ),
        child: const Center(
          child: Text(
            'No invoice found with that number.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final date = sale.createdAt?.toDate();
    final dateText = date == null
        ? '-'
        : '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x10000000), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Invoice #${sale.invoiceNumber}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
              Text(dateText,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const Divider(height: 28),
          _infoRow('Customer', sale.customerName.isEmpty
              ? 'Walk-in'
              : sale.customerName),
          _infoRow('Branch',
              sale.branchName.isEmpty ? '-' : sale.branchName),
          _infoRow('Payment Method', sale.paymentMethod),
          const SizedBox(height: 14),
          const Text('Items',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          ...sale.items.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.productName}  x${item.quantity}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    item.subtotal.toStringAsFixed(2),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 28),
          _infoRow('Total', sale.totalAmount.toStringAsFixed(2)),
          _infoRow('Discount', sale.discount.toStringAsFixed(2)),
          _infoRow('Net Amount', sale.netAmount.toStringAsFixed(2)),
          _infoRow('Paid', sale.paidAmount.toStringAsFixed(2)),
          _infoRow('Due', sale.dueAmount.toStringAsFixed(2),
              valueColor: sale.dueAmount > 0 ? Colors.red : Colors.green),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _deleting ? null : _delete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _deleting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.delete_outline),
              label: Text(_deleting ? 'Deleting...' : 'Delete Invoice'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}