import 'package:flutter/material.dart';
import '../../models/category.dart';
import '../../services/category_service.dart';
import '../../widgets/confirm_dialog.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final CategoryService _service = CategoryService();

  void _openForm({Category? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final urduController =
    TextEditingController(text: category?.urduName ?? '');
    final descController =
    TextEditingController(text: category?.description ?? '');
    String status = category?.status ?? 'active';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: Text(category == null ? 'Add Category' : 'Edit Category'),
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
                    decoration:
                    const InputDecoration(labelText: 'Category Name'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: urduController,
                    textDirection: TextDirection.rtl,
                    decoration:
                    const InputDecoration(labelText: 'Urdu Category'),
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

                final newCategory = Category(
                  id: category?.id ?? '',
                  name: nameController.text.trim(),
                  urduName: urduController.text.trim(),
                  description: descController.text.trim(),
                  status: status,
                  createdAt: category?.createdAt,
                );

                if (category == null) {
                  await _service.addCategory(newCategory);
                } else {
                  await _service.updateCategory(category.id, newCategory);
                }

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(category == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Category',
      message: 'Are you sure you want to delete "${category.name}"?',
    );
    if (confirmed) {
      await _service.deleteCategory(category.id);
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
                label: const Text('Add Category'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Category>>(
          stream: _service.streamCategories(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final categories = snapshot.data ?? [];

            if (categories.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No categories yet. Tap "Add Category" to create one.',
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
                          label: Text('ID',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Category',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Urdu Category',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Action',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: categories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value;
                      return DataRow(
                        color: index.isOdd
                            ? MaterialStateProperty.all(
                            const Color(0xFFFAFBFD))
                            : null,
                        cells: [
                          DataCell(Text('${index + 1}')),
                          DataCell(Text(category.name,
                              style:
                              const TextStyle(fontWeight: FontWeight.w600))),
                          DataCell(Text(category.urduName,
                              textDirection: TextDirection.rtl)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  onPressed: () =>
                                      _openForm(category: category),
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
                                  onPressed: () => _deleteCategory(category),
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