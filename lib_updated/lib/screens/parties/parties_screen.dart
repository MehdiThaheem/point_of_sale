import 'package:flutter/material.dart';
import '../../models/area.dart';
import '../../models/branch.dart';
import '../../models/customer.dart';
import '../../models/supplier.dart';
import '../../services/area_service.dart';
import '../../services/branch_service.dart';
import '../../services/customer_service.dart';
import '../../services/supplier_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/confirm_dialog.dart';

const Color _partyBlue = Color(0xFF3159C9);
const Color _partyGreen = Color(0xFF16A673);

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CustomerService _customerService = CustomerService();
  final SupplierService _supplierService = SupplierService();
  final AreaService _areaService = AreaService();
  final BranchService _branchService = BranchService();

  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openCustomerForm(
      {Customer? customer, required List<Branch> branchList}) {
    final nameController = TextEditingController(text: customer?.name ?? '');
    final businessController =
    TextEditingController(text: customer?.businessName ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final emailController = TextEditingController(text: customer?.email ?? '');
    final addressController =
    TextEditingController(text: customer?.address ?? '');
    String? selectedArea =
    customer?.area.isNotEmpty == true ? customer!.area : null;
    String? selectedFormBranchId =
    customer?.branchId.isNotEmpty == true ? customer!.branchId : null;
    String status = customer?.status ?? 'active';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<List<Area>>(
        stream: _areaService.streamAreas(),
        builder: (context, areaSnapshot) {
          final areas = areaSnapshot.data ?? [];

          return StatefulBuilder(
            builder: (ctx, setDialogState) => Dialog.fullscreen(
              backgroundColor: const Color(0xFFF5F7FA),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: _partyBlue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              customer == null
                                  ? 'Add Customer'
                                  : 'Edit Customer',
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
                              decoration:
                              const InputDecoration(labelText: 'Name'),
                              validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: businessController,
                              decoration: const InputDecoration(
                                  labelText: 'Business Name (optional)'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration:
                              const InputDecoration(labelText: 'Contact'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration:
                              const InputDecoration(labelText: 'Email'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: addressController,
                              decoration:
                              const InputDecoration(labelText: 'Address'),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: selectedFormBranchId,
                              decoration:
                              const InputDecoration(labelText: 'Branch'),
                              items: branchList
                                  .map((b) => DropdownMenuItem(
                                  value: b.id, child: Text(b.name)))
                                  .toList(),
                              onChanged: (v) => setDialogState(
                                      () => selectedFormBranchId = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: selectedArea,
                              decoration:
                              const InputDecoration(labelText: 'Area'),
                              items: areas
                                  .map((a) => DropdownMenuItem(
                                  value: a.name, child: Text(a.name)))
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => selectedArea = v),
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
                                    value: 'inactive',
                                    child: Text('Inactive')),
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

                              final branchName = selectedFormBranchId == null
                                  ? ''
                                  : branchList
                                  .firstWhere((b) =>
                              b.id == selectedFormBranchId)
                                  .name;

                              final newCustomer = Customer(
                                id: customer?.id ?? '',
                                name: nameController.text.trim(),
                                businessName: businessController.text.trim(),
                                phone: phoneController.text.trim(),
                                email: emailController.text.trim(),
                                address: addressController.text.trim(),
                                area: selectedArea ?? '',
                                branchId: selectedFormBranchId ?? '',
                                branchName: branchName,
                                totalReceivable:
                                customer?.totalReceivable ?? 0,
                                status: status,
                                createdAt: customer?.createdAt,
                              );

                              if (customer == null) {
                                await _customerService
                                    .addCustomer(newCustomer);
                              } else {
                                await _customerService.updateCustomer(
                                    customer.id, newCustomer);
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: Text(customer == null ? 'Add' : 'Save'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSupplierForm(
      {Supplier? supplier, required List<Branch> branchList}) {
    final nameController = TextEditingController(text: supplier?.name ?? '');
    final businessController =
    TextEditingController(text: supplier?.businessName ?? '');
    final phoneController = TextEditingController(text: supplier?.phone ?? '');
    final emailController = TextEditingController(text: supplier?.email ?? '');
    final addressController =
    TextEditingController(text: supplier?.address ?? '');
    String? selectedArea =
    supplier?.area.isNotEmpty == true ? supplier!.area : null;
    String? selectedFormBranchId =
    supplier?.branchId.isNotEmpty == true ? supplier!.branchId : null;
    String status = supplier?.status ?? 'active';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<List<Area>>(
        stream: _areaService.streamAreas(),
        builder: (context, areaSnapshot) {
          final areas = areaSnapshot.data ?? [];

          return StatefulBuilder(
            builder: (ctx, setDialogState) => Dialog.fullscreen(
              backgroundColor: const Color(0xFFF5F7FA),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: _partyBlue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              supplier == null
                                  ? 'Add Supplier'
                                  : 'Edit Supplier',
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
                              decoration:
                              const InputDecoration(labelText: 'Name'),
                              validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: businessController,
                              decoration: const InputDecoration(
                                  labelText: 'Business Name (optional)'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration:
                              const InputDecoration(labelText: 'Contact'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration:
                              const InputDecoration(labelText: 'Email'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: addressController,
                              decoration:
                              const InputDecoration(labelText: 'Address'),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: selectedFormBranchId,
                              decoration:
                              const InputDecoration(labelText: 'Branch'),
                              items: branchList
                                  .map((b) => DropdownMenuItem(
                                  value: b.id, child: Text(b.name)))
                                  .toList(),
                              onChanged: (v) => setDialogState(
                                      () => selectedFormBranchId = v),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: selectedArea,
                              decoration:
                              const InputDecoration(labelText: 'Area'),
                              items: areas
                                  .map((a) => DropdownMenuItem(
                                  value: a.name, child: Text(a.name)))
                                  .toList(),
                              onChanged: (v) =>
                                  setDialogState(() => selectedArea = v),
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
                                    value: 'inactive',
                                    child: Text('Inactive')),
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

                              final branchName = selectedFormBranchId == null
                                  ? ''
                                  : branchList
                                  .firstWhere((b) =>
                              b.id == selectedFormBranchId)
                                  .name;

                              final newSupplier = Supplier(
                                id: supplier?.id ?? '',
                                name: nameController.text.trim(),
                                businessName: businessController.text.trim(),
                                phone: phoneController.text.trim(),
                                email: emailController.text.trim(),
                                address: addressController.text.trim(),
                                area: selectedArea ?? '',
                                branchId: selectedFormBranchId ?? '',
                                branchName: branchName,
                                totalPayable: supplier?.totalPayable ?? 0,
                                status: status,
                                createdAt: supplier?.createdAt,
                              );

                              if (supplier == null) {
                                await _supplierService
                                    .addSupplier(newSupplier);
                              } else {
                                await _supplierService.updateSupplier(
                                    supplier.id, newSupplier);
                              }

                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: Text(supplier == null ? 'Add' : 'Save'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage Parties',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: _partyBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _partyBlue,
            tabs: const [
              Tab(text: 'Customers'),
              Tab(text: 'Suppliers'),
            ],
          ),
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
          height: 650,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCustomersTab(),
              _buildSuppliersTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomersTab() {
    return StreamBuilder<List<Branch>>(
      stream: _branchService.streamBranches(),
      builder: (context, branchSnapshot) {
        final branchList = branchSnapshot.data ?? [];

        return ValueListenableBuilder<String?>(
          valueListenable: selectedBranchId,
          builder: (context, branchFilter, _) {
            return StreamBuilder<List<Customer>>(
              stream: _customerService.streamCustomers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var customers = snapshot.data ?? [];
                if (branchFilter != null) {
                  customers = customers
                      .where((c) => c.branchId == branchFilter)
                      .toList();
                }
                if (_search.isNotEmpty) {
                  customers = customers
                      .where((c) =>
                  c.name.toLowerCase().contains(_search) ||
                      c.businessName.toLowerCase().contains(_search) ||
                      c.phone.toLowerCase().contains(_search))
                      .toList();
                }

                final total = customers.fold<double>(
                    0, (sum, c) => sum + c.totalReceivable);

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _openCustomerForm(branchList: branchList),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _partyGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Party'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _partyTable(
                        rows: customers
                            .map((c) => _PartyRow(
                          id: c.id,
                          name: c.name,
                          contact: c.phone,
                          address: c.address,
                          area: c.area,
                          branch: c.branchName,
                          amount: c.totalReceivable,
                          onEdit: () => _openCustomerForm(
                              customer: c, branchList: branchList),
                          onDelete: () async {
                            final confirmed = await showConfirmDialog(
                              context,
                              title: 'Delete Customer',
                              message:
                              'Are you sure you want to delete "${c.name}"?',
                            );
                            if (confirmed) {
                              await _customerService
                                  .deleteCustomer(c.id);
                            }
                          },
                        ))
                            .toList(),
                        total: total,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSuppliersTab() {
    return StreamBuilder<List<Branch>>(
      stream: _branchService.streamBranches(),
      builder: (context, branchSnapshot) {
        final branchList = branchSnapshot.data ?? [];

        return ValueListenableBuilder<String?>(
          valueListenable: selectedBranchId,
          builder: (context, branchFilter, _) {
            return StreamBuilder<List<Supplier>>(
              stream: _supplierService.streamSuppliers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var suppliers = snapshot.data ?? [];
                if (branchFilter != null) {
                  suppliers = suppliers
                      .where((s) => s.branchId == branchFilter)
                      .toList();
                }
                if (_search.isNotEmpty) {
                  suppliers = suppliers
                      .where((s) =>
                  s.name.toLowerCase().contains(_search) ||
                      s.businessName.toLowerCase().contains(_search) ||
                      s.phone.toLowerCase().contains(_search))
                      .toList();
                }

                final total = suppliers.fold<double>(
                    0, (sum, s) => sum + s.totalPayable);

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _openSupplierForm(branchList: branchList),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _partyGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Party'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _partyTable(
                        rows: suppliers
                            .map((s) => _PartyRow(
                          id: s.id,
                          name: s.name,
                          contact: s.phone,
                          address: s.address,
                          area: s.area,
                          branch: s.branchName,
                          amount: s.totalPayable,
                          onEdit: () => _openSupplierForm(
                              supplier: s, branchList: branchList),
                          onDelete: () async {
                            final confirmed = await showConfirmDialog(
                              context,
                              title: 'Delete Supplier',
                              message:
                              'Are you sure you want to delete "${s.name}"?',
                            );
                            if (confirmed) {
                              await _supplierService
                                  .deleteSupplier(s.id);
                            }
                          },
                        ))
                            .toList(),
                        total: total,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _partyTable({required List<_PartyRow> rows, required double total}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: _partyBlue,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: const Row(
              children: [
                _Cell('Party', flex: 3, header: true),
                _Cell('Contact', flex: 2, header: true),
                _Cell('Branch', flex: 2, header: true),
                _Cell('Amount', flex: 2, header: true),
                _Cell('Actions', flex: 2, header: true, center: true),
              ],
            ),
          ),
          if (rows.isEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: const Center(
                child: Text('No records found.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...rows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              return Container(
                color: index.isEven ? Colors.white : const Color(0xFFF7F9FC),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Cell(row.name, flex: 3, subtitle: row.address),
                    _Cell(row.contact.isEmpty ? '-' : row.contact, flex: 2),
                    _Cell(row.branch.isEmpty ? '-' : row.branch, flex: 2,
                        subtitle: row.area),
                    _Cell(
                      row.amount.toStringAsFixed(0),
                      flex: 2,
                      color: row.amount > 0 ? Colors.red : Colors.grey,
                      bold: true,
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: row.onEdit,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.edit_outlined,
                                  size: 16, color: _partyBlue),
                            ),
                          ),
                          InkWell(
                            onTap: row.onDelete,
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
          Container(
            color: _partyBlue,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  flex: 7,
                  child: Text('Total',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    total.toStringAsFixed(2),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const Expanded(flex: 2, child: SizedBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyRow {
  final String id;
  final String name;
  final String contact;
  final String address;
  final String area;
  final String branch;
  final double amount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  _PartyRow({
    required this.id,
    required this.name,
    required this.contact,
    required this.address,
    required this.area,
    required this.branch,
    required this.amount,
    required this.onEdit,
    required this.onDelete,
  });
}

class _Cell extends StatelessWidget {
  final String text;
  final String? subtitle;
  final int flex;
  final bool header;
  final bool center;
  final bool bold;
  final Color? color;

  const _Cell(
      this.text, {
        required this.flex,
        this.subtitle,
        this.header = false,
        this.center = false,
        this.bold = false,
        this.color,
      });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment:
        center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: center ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: header ? Colors.white : (color ?? Colors.black87),
              fontWeight: header || bold ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
        ],
      ),
    );
  }
}