import 'package:flutter/material.dart';
import '../../models/salary_payment.dart';
import '../../services/salary_service.dart';
import '../../widgets/confirm_dialog.dart';

class SalarySheetScreen extends StatefulWidget {
  const SalarySheetScreen({super.key});

  @override
  State<SalarySheetScreen> createState() => _SalarySheetScreenState();
}

class _SalarySheetScreenState extends State<SalarySheetScreen> {
  final SalaryService _service = SalaryService();
  String? _monthFilter;

  Future<void> _deletePayment(SalaryPayment payment) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Salary Record',
      message:
      'Remove the salary payment for "${payment.employeeName}" (${payment.month})?',
    );
    if (confirmed) {
      await _service.deleteSalaryPayment(payment.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Salary Sheet',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'History of all generated salary payments.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<SalaryPayment>>(
          stream: _service.streamSalaryPayments(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final allPayments = snapshot.data ?? [];

            if (allPayments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No salary payments generated yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            final months = allPayments.map((p) => p.month).toSet().toList();
            final payments = _monthFilter == null
                ? allPayments
                : allPayments.where((p) => p.month == _monthFilter).toList();

            final total =
            payments.fold<double>(0, (sum, p) => sum + p.amount);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _monthFilter,
                        decoration:
                        const InputDecoration(labelText: 'Filter by Month'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('All Months')),
                          ...months.map((m) =>
                              DropdownMenuItem(value: m, child: Text(m))),
                        ],
                        onChanged: (v) => setState(() => _monthFilter = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Total Paid: ${total.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: payments.map((payment) {
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x1A7B61C9),
                          child: Icon(Icons.payments_outlined,
                              color: Colors.deepPurple),
                        ),
                        title: Text(payment.employeeName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(payment.month),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              payment.amount.toStringAsFixed(0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 18),
                              onPressed: () => _deletePayment(payment),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}