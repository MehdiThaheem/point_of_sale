import 'package:flutter/material.dart';
import '../../models/purchase.dart';
import '../../services/purchase_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/pro_ui.dart';
import 'new_purchase_screens.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  final PurchaseService _service = PurchaseService();
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openNew() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewPurchaseScreen()),
    );
  }

  Future<void> _delete(Purchase p) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Purchase',
      message:
      'Delete the purchase from "${p.supplierName}"? This will reverse the '
          'stock and supplier balance changes.',
    );
    if (!ok) return;
    try {
      await _service.deletePurchase(p);
      if (mounted) Pro.snack(context, 'Purchase deleted.', color: Pro.green);
    } catch (e) {
      if (mounted) Pro.snack(context, 'Error: $e');
    }
  }

  void _view(Purchase p) {
    showDialog<void>(
      context: context,
      builder: (_) => ProDialog(
        title: 'Purchase Details',
        icon: Icons.shopping_bag_outlined,
        width: 720,
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 30,
              runSpacing: 10,
              children: [
                _info('Supplier', p.supplierName),
                _info('Date', Pro.date(p.createdAt?.toDate())),
                _info('Branch', p.branchName.isEmpty ? '-' : p.branchName),
              ],
            ),
            const SizedBox(height: 16),
            ProTable(
              minWidth: 520,
              columns: const [
                ProCol('Item', 30),
                ProCol('Type', 16),
                ProCol('Qty', 12, align: Alignment.centerRight),
                ProCol('Unit Cost', 17, align: Alignment.centerRight),
                ProCol('Subtotal', 17, align: Alignment.centerRight),
              ],
              rows: [
                for (final i in p.items)
                  [
                    Pro.t(i.itemName, bold: true),
                    Pro.t(i.itemType == 'raw_material'
                        ? 'Raw Material'
                        : 'Product'),
                    Pro.t(Pro.qty(i.quantity), align: TextAlign.right),
                    Pro.t(Pro.money(i.unitCost, decimals: 2),
                        align: TextAlign.right),
                    Pro.t(Pro.money(i.subtotal),
                        bold: true, align: TextAlign.right),
                  ],
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total: ${Pro.money(p.totalAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Paid: ${Pro.money(p.paidAmount)}',
                      style: const TextStyle(color: Pro.green)),
                  Text('Due: ${Pro.money(p.dueAmount)}',
                      style: TextStyle(
                          color: p.dueAmount > 0 ? Pro.red : Pro.grey,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Pro.grey, fontSize: 12)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }

  String _statusLabel(Purchase p) {
    if (p.dueAmount <= 0) return 'Paid';
    if (p.paidAmount > 0) return 'Partial';
    return 'Unpaid';
  }

  Color _statusColor(Purchase p) {
    if (p.dueAmount <= 0) return Pro.green;
    if (p.paidAmount > 0) return Pro.orange;
    return Pro.red;
  }

  @override
  Widget build(BuildContext context) {
    // Follows the branch chosen in the top bar.
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchId, _) {
        return StreamBuilder<List<Purchase>>(
          stream: _service.streamPurchases(),
          builder: (context, snapshot) {
            final loading =
                snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

            var all = snapshot.data ?? <Purchase>[];
            if (branchId != null) {
              all = all.where((p) => p.branchId == branchId).toList();
            }

            final q = _search.text.trim().toLowerCase();
            final list = q.isEmpty
                ? all
                : all
                .where((p) => p.supplierName.toLowerCase().contains(q))
                .toList();

            final total = list.fold<double>(0, (s, p) => s + p.totalAmount);
            final paid = list.fold<double>(0, (s, p) => s + p.paidAmount);
            final due = list.fold<double>(0, (s, p) => s + p.dueAmount);
            final showBranch = branchId == null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProHeader(
                  title: 'Purchases',
                  subtitle: selectedBranchName.value ?? 'All Branches',
                  actions: [
                    Pro.button('New Purchase', Icons.add, _openNew),
                  ],
                ),
                const SizedBox(height: 18),
                ProStatRow([
                  ProStat('Total Purchases', Pro.money(total),
                      Icons.shopping_bag_outlined, Pro.blue),
                  ProStat('Paid', Pro.money(paid), Icons.check_circle_outline,
                      Pro.green),
                  ProStat('Due', Pro.money(due),
                      Icons.pending_actions_outlined, Pro.red),
                  ProStat('Invoices', '${list.length}',
                      Icons.receipt_long_outlined, Pro.orange),
                ]),
                const SizedBox(height: 18),
                ProCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProSearch(
                        controller: _search,
                        hint: 'Search supplier...',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        ProTable(
                          minWidth: showBranch ? 1000 : 880,
                          emptyText:
                          'No purchases found. Tap "New Purchase" to record one.',
                          columns: [
                            const ProCol('Sr#', 6, align: Alignment.center),
                            const ProCol('Date', 12),
                            const ProCol('Supplier', 18),
                            if (showBranch) const ProCol('Branch', 12),
                            const ProCol('Items', 7, align: Alignment.center),
                            const ProCol('Total', 11,
                                align: Alignment.centerRight),
                            const ProCol('Paid', 11,
                                align: Alignment.centerRight),
                            const ProCol('Due', 11,
                                align: Alignment.centerRight),
                            const ProCol('Status', 10,
                                align: Alignment.center),
                            const ProCol('Action', 12,
                                align: Alignment.center),
                          ],
                          rows: [
                            for (var i = 0; i < list.length; i++)
                              _row(i, list[i], showBranch),
                          ],
                          footer: [
                            const SizedBox(),
                            const SizedBox(),
                            Pro.t('Total', bold: true),
                            if (showBranch) const SizedBox(),
                            const SizedBox(),
                            Pro.t(Pro.money(total),
                                bold: true, align: TextAlign.right),
                            Pro.t(Pro.money(paid),
                                bold: true, align: TextAlign.right),
                            Pro.t(Pro.money(due),
                                bold: true,
                                color: due > 0 ? Pro.red : null,
                                align: TextAlign.right),
                            const SizedBox(),
                            const SizedBox(),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _row(int i, Purchase p, bool showBranch) {
    return [
      Pro.t('${i + 1}', align: TextAlign.center),
      Pro.t(Pro.date(p.createdAt?.toDate())),
      Pro.t(p.supplierName, bold: true),
      if (showBranch) Pro.t(p.branchName.isEmpty ? '-' : p.branchName),
      Pro.t('${p.items.length}', align: TextAlign.center),
      Pro.t(Pro.money(p.totalAmount), align: TextAlign.right),
      Pro.t(Pro.money(p.paidAmount), align: TextAlign.right),
      Pro.t(Pro.money(p.dueAmount),
          align: TextAlign.right, color: p.dueAmount > 0 ? Pro.red : null),
      ProChip(_statusLabel(p), _statusColor(p)),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'View details',
            visualDensity: VisualDensity.compact,
            onPressed: () => _view(p),
            icon: const Icon(Icons.visibility_outlined,
                size: 20, color: Pro.blue),
          ),
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            onPressed: () => _delete(p),
            icon: const Icon(Icons.delete_outline, size: 20, color: Pro.red),
          ),
        ],
      ),
    ];
  }
}