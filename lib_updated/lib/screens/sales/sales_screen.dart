import 'package:flutter/material.dart';
import '../../models/sales.dart';
import '../../services/sale_service.dart';
import '../../widgets/confirm_dialog.dart';
import 'new_sale_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SaleService _service = SaleService();

  Future<void> _deleteSale(Sale sale) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Sale',
      message:
      'This will reverse the stock and customer balance changes. Continue?',
    );
    if (confirmed) {
      await _service.deleteSale(sale);
    }
  }

  void _viewSale(Sale sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Invoice #${sale.invoiceNumber}'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Customer', sale.customerName),
                if (sale.poNumber.isNotEmpty) _row('PO #', sale.poNumber),
                _row('Payment', sale.paymentMethod),
                const Divider(height: 20),
                ...sale.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(
                              '${item.productName} × ${item.quantity.toStringAsFixed(0)}')),
                      Text(item.subtotal.toStringAsFixed(0)),
                    ],
                  ),
                )),
                const Divider(height: 20),
                _row('Total', sale.totalAmount.toStringAsFixed(0)),
                if (sale.discount > 0)
                  _row('Discount', sale.discount.toStringAsFixed(0)),
                _row('Net', sale.netAmount.toStringAsFixed(0), bold: true),
                _row('Paid', sale.paidAmount.toStringAsFixed(0)),
                _row('Due', sale.dueAmount.toStringAsFixed(0),
                    color: sale.dueAmount > 0 ? Colors.red : Colors.grey),
              ],
            ),
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

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Sales',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewSaleScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('New Sale'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Sale>>(
          stream: _service.streamSales(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final sales = snapshot.data ?? [];

            if (sales.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No sales yet. Tap "New Sale" to record one, or make '
                        'one from the Counter Sale / Sale screens.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Card(
              child: Column(
                children: sales.map((sale) {
                  return ListTile(
                    onTap: () => _viewSale(sale),
                    leading: CircleAvatar(
                      backgroundColor: sale.dueAmount > 0
                          ? Colors.red.withOpacity(0.15)
                          : Colors.green.withOpacity(0.15),
                      child: Icon(
                        Icons.point_of_sale_outlined,
                        color:
                        sale.dueAmount > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                    title: Text(
                        '#${sale.invoiceNumber} · ${sale.customerName}',
                        style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${sale.items.length} item(s)  •  ${sale.paymentMethod}'
                          '  •  Net: ${sale.netAmount.toStringAsFixed(0)}'
                          '  •  Due: ${sale.dueAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: sale.dueAmount > 0 ? Colors.red : Colors.grey,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined,
                              color: Color(0xFF2F5FDE)),
                          onPressed: () => _viewSale(sale),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () => _deleteSale(sale),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}