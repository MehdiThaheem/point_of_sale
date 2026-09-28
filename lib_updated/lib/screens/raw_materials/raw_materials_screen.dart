import 'package:flutter/material.dart';
import '../../models/raw_material.dart';
import '../../services/raw_material_service.dart';
import '../../widgets/confirm_dialog.dart';

class RawMaterialsScreen extends StatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  State<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends State<RawMaterialsScreen> {
  final RawMaterialService _service = RawMaterialService();

  void _openForm({RawMaterial? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final unitController =
    TextEditingController(text: item?.unit ?? 'kg');
    final stockController =
    TextEditingController(text: item?.currentStock.toString() ?? '0');
    final minStockController =
    TextEditingController(text: item?.minStock.toString() ?? '0');
    final costController =
    TextEditingController(text: item?.costPerUnit.toString() ?? '0');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFFF5F7FA),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF3159C9),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item == null
                            ? 'Add Raw Material'
                            : 'Edit Raw Material',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: unitController,
                        decoration: const InputDecoration(
                            labelText: 'Unit (kg, litre, pcs...)'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Current Stock'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: minStockController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Min Stock'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: costController,
                        keyboardType: TextInputType.number,
                        decoration:
                        const InputDecoration(labelText: 'Cost per Unit'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        final newItem = RawMaterial(
                          id: item?.id ?? '',
                          name: nameController.text.trim(),
                          unit: unitController.text.trim(),
                          currentStock:
                          double.tryParse(stockController.text.trim()) ??
                              0,
                          minStock: double.tryParse(
                              minStockController.text.trim()) ??
                              0,
                          costPerUnit:
                          double.tryParse(costController.text.trim()) ??
                              0,
                          createdAt: item?.createdAt,
                        );

                        if (item == null) {
                          await _service.addRawMaterial(newItem);
                        } else {
                          await _service.updateRawMaterial(item.id, newItem);
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(item == null ? 'Add' : 'Save'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(RawMaterial item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Raw Material',
      message: 'Are you sure you want to delete "${item.name}"?',
    );
    if (confirmed) {
      await _service.deleteRawMaterial(item.id);
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
                'Raw Materials',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Raw Material'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<RawMaterial>>(
          stream: _service.streamRawMaterials(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No raw materials yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return Card(
              child: Column(
                children: items.map((item) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.isLowStock
                          ? Colors.red.withOpacity(0.15)
                          : Colors.blue.withOpacity(0.15),
                      child: Icon(
                        Icons.category_outlined,
                        color: item.isLowStock ? Colors.red : Colors.blue,
                      ),
                    ),
                    title: Text(item.name,
                        style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Stock: ${item.currentStock} ${item.unit}  •  Cost: ${item.costPerUnit}/${item.unit}'
                          '${item.isLowStock ? '  •  LOW STOCK' : ''}',
                      style: TextStyle(
                        color: item.isLowStock ? Colors.red : Colors.grey,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openForm(item: item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () => _deleteItem(item),
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