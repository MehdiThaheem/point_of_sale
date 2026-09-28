import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../../services/supplier_service.dart';
import '../../widgets/confirm_dialog.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final SupplierService _service = SupplierService();

  void _openForm({Supplier? supplier}) {
    final nameController = TextEditingController(text: supplier?.name ?? '');
    final businessController =
    TextEditingController(text: supplier?.businessName ?? '');
    final phoneController = TextEditingController(text: supplier?.phone ?? '');
    final emailController = TextEditingController(text: supplier?.email ?? '');
    final addressController =
    TextEditingController(text: supplier?.address ?? '');
    String status = supplier?.status ?? 'active';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(supplier == null ? 'Add Supplier' : 'Edit Supplier'),
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

                final newSupplier = Supplier(
                  id: supplier?.id ?? '',
                  name: nameController.text.trim(),
                  businessName: businessController.text.trim(),
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  address: addressController.text.trim(),
                  totalPayable: supplier?.totalPayable ?? 0,
                  status: status,
                  createdAt: supplier?.createdAt,
                );

                if (supplier == null) {
                  await _service.addSupplier(newSupplier);
                } else {
                  await _service.updateSupplier(supplier.id, newSupplier);
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(supplier == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSupplier(Supplier supplier) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Supplier',
      message: 'Are you sure you want to delete "${supplier.name}"?',
    );
    if (confirmed) {
      await _service.deleteSupplier(supplier.id);
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
                'Suppliers',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Supplier'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Supplier>>(
          stream: _service.streamSuppliers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final suppliers = snapshot.data ?? [];

            if (suppliers.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No suppliers yet. Tap "Add Supplier" to create one.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Card(
              child: Column(
                children: suppliers.map((supplier) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: supplier.status == 'active'
                          ? Colors.purple.withOpacity(0.15)
                          : Colors.grey.withOpacity(0.15),
                      child: Icon(
                        Icons.local_shipping_outlined,
                        color: supplier.status == 'active'
                            ? Colors.purple
                            : Colors.grey,
                      ),
                    ),
                    title: Text(
                      supplier.businessName.isEmpty
                          ? supplier.name
                          : '${supplier.name} (${supplier.businessName})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${supplier.phone.isEmpty ? "No phone" : supplier.phone}'
                          '  •  Payable: ${supplier.totalPayable.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: supplier.totalPayable > 0
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openForm(supplier: supplier),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () => _deleteSupplier(supplier),
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