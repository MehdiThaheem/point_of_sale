import 'package:flutter/material.dart';
import '../../models/area.dart';
import '../../services/area_service.dart';
import '../../widgets/confirm_dialog.dart';

const Color _areaBlue = Color(0xFF3159C9);
const Color _areaGreen = Color(0xFF16A673);

class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  final AreaService _service = AreaService();
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openForm({Area? area}) {
    final nameController = TextEditingController(text: area?.name ?? '');
    final descController =
    TextEditingController(text: area?.description ?? '');
    String status = area?.status ?? 'active';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog.fullscreen(
          backgroundColor: const Color(0xFFF5F7FA),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: _areaBlue,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          area == null ? 'Add Area' : 'Edit Area',
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
                          decoration: const InputDecoration(
                              labelText: 'Area Name (city, zone, branch...)'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
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
                          decoration:
                          const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(
                                value: 'active', child: Text('Active')),
                            DropdownMenuItem(
                                value: 'inactive', child: Text('Inactive')),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => status = v!),
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

                          final newArea = Area(
                            id: area?.id ?? '',
                            name: nameController.text.trim(),
                            description: descController.text.trim(),
                            status: status,
                            createdAt: area?.createdAt,
                          );

                          if (area == null) {
                            await _service.addArea(newArea);
                          } else {
                            await _service.updateArea(area.id, newArea);
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(area == null ? 'Add' : 'Save'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteArea(Area area) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Area',
      message: 'Are you sure you want to delete "${area.name}"?',
    );
    if (confirmed) {
      await _service.deleteArea(area.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage Areas',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search...',
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openForm(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _areaGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Area'),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<Area>>(
          stream: _service.streamAreas(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            var areas = snapshot.data ?? [];
            if (_search.isNotEmpty) {
              areas = areas
                  .where((a) => a.name.toLowerCase().contains(_search))
                  .toList();
            }

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 8),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    color: _areaBlue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: const Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: Text('Area Name',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 4,
                            child: Text('Description',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 2,
                            child: Text('Status',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))),
                        Expanded(
                            flex: 2,
                            child: Text('Actions',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  if (areas.isEmpty)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: const Center(
                        child: Text('No areas yet.',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ...areas.asMap().entries.map((entry) {
                      final index = entry.key;
                      final area = entry.value;
                      return Container(
                        color: index.isEven
                            ? Colors.white
                            : const Color(0xFFF7F9FC),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(area.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                area.description.isEmpty
                                    ? '-'
                                    : area.description,
                                style: const TextStyle(color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: area.status == 'active'
                                      ? Colors.green.withOpacity(0.12)
                                      : Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  area.status == 'active'
                                      ? 'Active'
                                      : 'Inactive',
                                  style: TextStyle(
                                    color: area.status == 'active'
                                        ? Colors.green
                                        : Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () => _openForm(area: area),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.edit_outlined,
                                          size: 16, color: _areaBlue),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _deleteArea(area),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.delete_outline,
                                          size: 16, color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}