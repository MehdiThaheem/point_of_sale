import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/confirm_dialog.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderService _service = OrderService();

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Future<void> _deleteOrder(CustomerOrder order) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Order',
      message: 'Are you sure you want to delete this order?',
    );
    if (confirmed) {
      await _service.deleteOrder(order.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Orders',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Orders placed by customers appear here. Approve them, then '
              'record the final sale from the Sales tab once fulfilled.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<CustomerOrder>>(
          stream: _service.streamOrders(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final orders = snapshot.data ?? [];

            if (orders.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No orders yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Column(
              children: orders.map((order) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.customerName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(order.status)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                order.status.toUpperCase(),
                                style: TextStyle(
                                  color: _statusColor(order.status),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...order.items.map((item) => Padding(
                          padding:
                          const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${item.productName}  x${item.quantity}  =  ${item.subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Text(
                              'Total: ${order.totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (order.status == 'pending') ...[
                              TextButton(
                                onPressed: () => _service.updateStatus(
                                    order.id, 'rejected'),
                                child: const Text('Reject',
                                    style:
                                    TextStyle(color: Colors.redAccent)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _service.updateStatus(
                                    order.id, 'approved'),
                                child: const Text('Approve'),
                              ),
                            ] else if (order.status == 'approved') ...[
                              ElevatedButton(
                                onPressed: () => _service.updateStatus(
                                    order.id, 'completed'),
                                child: const Text('Mark Completed'),
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () => _deleteOrder(order),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}