import 'package:flutter/material.dart';
import '../../models/purchase.dart';
import '../../services/purchase_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/confirm_dialog.dart';
import 'new_purchase_screens.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final PurchaseService _service = PurchaseService();

  Future<void> _deletePurchase(Purchase purchase) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Purchase',
      message:
      'This will reverse the stock and supplier balance changes. Continue?',
    );
    if (confirmed) {
      await _service.deletePurchase(purchase);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchFilter, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Purchases',
                    style:
                    TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NewPurchaseScreen()),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Purchase'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<Purchase>>(
              stream: _service.streamPurchases(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                var purchases = snapshot.data ?? [];
                if (branchFilter != null) {
                  purchases = purchases
                      .where((p) => p.branchId == branchFilter)
                      .toList();
                }

                if (purchases.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'No purchases yet. Tap "New Purchase" to record one.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return Card(
                  child: Column(
                    children: purchases.map((purchase) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: purchase.dueAmount > 0
                              ? Colors.red.withOpacity(0.15)
                              : Colors.green.withOpacity(0.15),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: purchase.dueAmount > 0
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                        title: Text(purchase.supplierName,
                            style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${purchase.branchName.isEmpty ? "" : "${purchase.branchName} • "}'
                              '${purchase.items.length} item(s)  •  Total: ${purchase.totalAmount.toStringAsFixed(0)}'
                              '  •  Due: ${purchase.dueAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: purchase.dueAmount > 0
                                ? Colors.red
                                : Colors.grey,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () => _deletePurchase(purchase),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}