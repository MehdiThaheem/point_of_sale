import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../services/customer_service.dart';
import '../../widgets/confirm_dialog.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final CustomerService _service = CustomerService();

  void _openForm({Customer? customer}) {
    final nameController = TextEditingController(text: customer?.name ?? '');
    final businessController =
    TextEditingController(text: customer?.businessName ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final addressController =
    TextEditingController(text: customer?.address ?? '');
    String status = customer?.status ?? 'active';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(customer == null ? 'Add Customer' : 'Edit Customer'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: MediaQuery.of(context).size.width < 500
                  ? MediaQuery.of(context).size.width * 0.85
                  : 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration:
                      const InputDecoration(labelText: 'Contact Name'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: businessController,
                      decoration: const InputDecoration(
                          labelText: 'Business / Company Name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                            value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'inactive', child: Text('Inactive')),
                      ],
                      onChanged: (v) => setDialogState(() => status = v!),
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

                final newCustomer = Customer(
                  id: customer?.id ?? '',
                  name: nameController.text.trim(),
                  businessName: businessController.text.trim(),
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  address: addressController.text.trim(),
                  totalReceivable: customer?.totalReceivable ?? 0,
                  status: status,
                  createdAt: customer?.createdAt,
                );

                if (customer == null) {
                  await _service.addCustomer(newCustomer);
                } else {
                  await _service.updateCustomer(customer.id, newCustomer);
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(customer == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Customer',
      message: 'Are you sure you want to delete "${customer.name}"?',
    );
    if (confirmed) {
      await _service.deleteCustomer(customer.id);
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
                'Customers',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Customer'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Customer>>(
          stream: _service.streamCustomers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final customers = snapshot.data ?? [];

            if (customers.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No customers yet. Tap "Add Customer" to create one.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Card(
              child: Column(
                children: customers.map((customer) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: customer.status == 'active'
                          ? Colors.orange.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                      child: Icon(
                        Icons.person_outline,
                        color: customer.status == 'active'
                            ? Colors.orange
                            : Colors.grey,
                      ),
                    ),
                    title: Text(
                      customer.businessName.isEmpty
                          ? customer.name
                          : '${customer.name} (${customer.businessName})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${customer.phone.isEmpty ? "No phone" : customer.phone}'
                          '  •  Receivable: ${customer.totalReceivable.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: customer.totalReceivable > 0
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openForm(customer: customer),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () => _deleteCustomer(customer),
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