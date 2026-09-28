import 'package:flutter/material.dart';
import '../../models/expense.dart';
import '../../models/purchase.dart';
import '../../models/salary_payment.dart';
import '../../models/sales.dart';
import '../../services/expense_service.dart';
import '../../services/purchase_service.dart';
import '../../services/sale_service.dart';
import '../../services/salary_service.dart';

class AccountingSystemScreen extends StatefulWidget {
  const AccountingSystemScreen({super.key});

  @override
  State<AccountingSystemScreen> createState() =>
      _AccountingSystemScreenState();
}

class _AccountingSystemScreenState extends State<AccountingSystemScreen> {
  final SaleService _saleService = SaleService();
  final PurchaseService _purchaseService = PurchaseService();
  final ExpenseService _expenseService = ExpenseService();
  final SalaryService _salaryService = SalaryService();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accounting System',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Income vs. expenses overview.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Sale>>(
          stream: _saleService.streamSales(),
          builder: (context, saleSnapshot) {
            final sales = saleSnapshot.data ?? [];
            final totalIncome =
            sales.fold<double>(0, (sum, s) => sum + s.totalAmount);

            return StreamBuilder<List<Purchase>>(
              stream: _purchaseService.streamPurchases(),
              builder: (context, purchaseSnapshot) {
                final purchases = purchaseSnapshot.data ?? [];
                final totalPurchases = purchases.fold<double>(
                    0, (sum, p) => sum + p.totalAmount);

                return StreamBuilder<List<Expense>>(
                  stream: _expenseService.streamExpenses(),
                  builder: (context, expenseSnapshot) {
                    final expenses = expenseSnapshot.data ?? [];
                    final totalExpenses = expenses.fold<double>(
                        0, (sum, e) => sum + e.amount);

                    return StreamBuilder<List<SalaryPayment>>(
                      stream: _salaryService.streamSalaryPayments(),
                      builder: (context, salarySnapshot) {
                        final salaries = salarySnapshot.data ?? [];
                        final totalSalaries = salaries.fold<double>(
                            0, (sum, s) => sum + s.amount);

                        final totalOutgoing = totalPurchases +
                            totalExpenses +
                            totalSalaries;
                        final netProfit = totalIncome - totalOutgoing;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GridView(
                              gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                crossAxisSpacing: 5,
                                mainAxisSpacing: 3,
                                childAspectRatio: 1.5,
                              ),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _card('Income (Sales)', totalIncome,
                                    Colors.green, Icons.trending_up),
                                _card('Purchases', totalPurchases,
                                    Colors.orange,
                                    Icons.shopping_bag_outlined),
                                _card('Expenses', totalExpenses, Colors.red,
                                    Icons.receipt_outlined),
                                _card('Salaries Paid', totalSalaries,
                                    Colors.purple, Icons.payments_outlined),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: netProfit >= 0
                                    ? Colors.green.withOpacity(0.08)
                                    : Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    netProfit >= 0
                                        ? 'Net Profit'
                                        : 'Net Loss',
                                    style: const TextStyle(
                                        color: Colors.grey),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    netProfit.abs().toStringAsFixed(0),
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: netProfit >= 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Income − (Purchases + Expenses + Salaries)',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12),
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
              },
            );
          },
        ),
      ],
    );
  }

  Widget _card(String title, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value.toStringAsFixed(0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}