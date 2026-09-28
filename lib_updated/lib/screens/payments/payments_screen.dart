import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../services/payment_service.dart';
import '../../models/supplier.dart';
import '../../services/customer_service.dart';
import '../../services/supplier_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../models/payments.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final PaymentService _service = PaymentService();
  final CustomerService _customerService = CustomerService();
  final SupplierService _supplierService = SupplierService();

  void _openForm() {
    String partyType = 'customer';
    dynamic selectedParty;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<List<Customer>>(
        stream: _customerService.streamCustomers(),
        builder: (context, customerSnapshot) {
          final customers = customerSnapshot.data ?? [];

          return StreamBuilder<List<Supplier>>(
            stream: _supplierService.streamSuppliers(),
            builder: (context, supplierSnapshot) {
              final suppliers = supplierSnapshot.data ?? [];

              return StatefulBuilder(
                builder: (ctx, setDialogState) {
                  final currentList =
                  partyType == 'customer' ? customers : suppliers;

                  return AlertDialog(
                    title: const Text('Record Payment'),
                    content: Form(
                      key: formKey,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width < 460
                            ? MediaQuery.of(context).size.width * 0.85
                            : 400,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ChoiceChip(
                                      label: const Text(
                                          'Receive from Customer'),
                                      selected: partyType == 'customer',
                                      onSelected: (_) => setDialogState(() {
                                        partyType = 'customer';
                                        selectedParty = null;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ChoiceChip(
                                      label: const Text('Pay to Supplier'),
                                      selected: partyType == 'supplier',
                                      onSelected: (_) => setDialogState(() {
                                        partyType = 'supplier';
                                        selectedParty = null;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (currentList.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'No records found. Add one first.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              else
                                DropdownButtonFormField(
                                  value: selectedParty,
                                  decoration: InputDecoration(
                                    labelText: partyType == 'customer'
                                        ? 'Customer'
                                        : 'Supplier',
                                  ),
                                  items: currentList.map((p) {
                                    final name = p is Customer
                                        ? p.name
                                        : (p as Supplier).name;
                                    final balance = p is Customer
                                        ? p.totalReceivable
                                        : (p as Supplier).totalPayable;
                                    return DropdownMenuItem(
                                      value: p,
                                      child: Text(
                                          '$name (${balance.toStringAsFixed(0)})'),
                                    );
                                  }).toList(),
                                  onChanged: (v) =>
                                      setDialogState(() => selectedParty = v),
                                ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                decoration:
                                const InputDecoration(labelText: 'Amount'),
                                validator: (v) {
                                  final val = double.tryParse(v ?? '');
                                  if (val == null || val <= 0) {
                                    return 'Enter a valid amount';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: noteController,
                                decoration: const InputDecoration(
                                    labelText: 'Note (optional)'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          if (selectedParty == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Select a party.')),
                            );
                            return;
                          }

                          final id = selectedParty is Customer
                              ? (selectedParty as Customer).id
                              : (selectedParty as Supplier).id;
                          final name = selectedParty is Customer
                              ? (selectedParty as Customer).name
                              : (selectedParty as Supplier).name;

                          final payment = Payment(
                            id: '',
                            partyType: partyType,
                            partyId: id,
                            partyName: name,
                            amount:
                            double.parse(amountController.text.trim()),
                            note: noteController.text.trim(),
                          );

                          await _service.addPayment(payment);

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Save'),
                      ),
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

  Future<void> _deletePayment(Payment payment) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Payment',
      message: 'This will restore the party\'s balance. Continue?',
    );
    if (confirmed) {
      await _service.deletePayment(payment);
    }
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
                'Payments',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Record Payment'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Payment>>(
          stream: _service.streamPayments(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final payments = snapshot.data ?? [];

            if (payments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No payments recorded yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Card(
              child: Column(
                children: payments.map((payment) {
                  final isCustomer = payment.partyType == 'customer';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isCustomer
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      child: Icon(
                        isCustomer
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: isCustomer ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Text(payment.partyName,
                        style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${isCustomer ? "Received" : "Paid"}: ${payment.amount.toStringAsFixed(0)}'
                          '${payment.note.isNotEmpty ? '  •  ${payment.note}' : ''}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: () => _deletePayment(payment),
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