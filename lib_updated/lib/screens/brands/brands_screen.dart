import 'package:flutter/material.dart';
import '../../models/brand.dart';
import '../../services/brand_service.dart';
import '../../widgets/confirm_dialog.dart';

class BrandsScreen extends StatefulWidget {
  const BrandsScreen({super.key});

  @override
  State<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> {
  final BrandService _service = BrandService();

  void _openForm({Brand? brand}) {
    final nameController = TextEditingController(text: brand?.name ?? '');
    final descController =
    TextEditingController(text: brand?.description ?? '');
    String status = brand?.status ?? 'active';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: Text(brand == null ? 'Add Brand' : 'Edit Brand'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: MediaQuery.of(context).size.width < 460
                  ? MediaQuery.of(context).size.width * 0.85
                  : 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Brand Name'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    decoration:
                    const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('Inactive')),
                    ],
                    onChanged: (v) => setDialogState(() => status = v!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F5FDE),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final newBrand = Brand(
                  id: brand?.id ?? '',
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  status: status,
                  createdAt: brand?.createdAt,
                );

                if (brand == null) {
                  await _service.addBrand(newBrand);
                } else {
                  await _service.updateBrand(brand.id, newBrand);
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(brand == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBrand(Brand brand) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Brand',
      message: 'Are you sure you want to delete "${brand.name}"?',
    );
    if (confirmed) {
      await _service.deleteBrand(brand.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE7EAF0)),
          ),
          child: Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F5FDE),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Brand'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Brand>>(
          stream: _service.streamBrands(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Error: ${snapshot.error}'),
              );
            }

            final brands = snapshot.data ?? [];

            if (brands.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No brands yet. Tap "Add Brand" to create one.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE7EAF0)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 32),
                  child: DataTable(
                    headingRowColor:
                    MaterialStateProperty.all(const Color(0xFFF5F7FA)),
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 64,
                    columns: const [
                      DataColumn(
                          label: Text('Brand ID',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Brand Name',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Action',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: brands.asMap().entries.map((entry) {
                      final index = entry.key;
                      final brand = entry.value;
                      return DataRow(
                        color: index.isOdd
                            ? MaterialStateProperty.all(
                            const Color(0xFFFAFBFD))
                            : null,
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Text(brand.name,
                              style:
                              const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _openForm(brand: brand),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2F5FDE),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Edit'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _deleteBrand(brand),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE5484D),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}