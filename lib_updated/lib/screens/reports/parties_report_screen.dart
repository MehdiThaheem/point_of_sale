import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../models/customer.dart';
import '../../models/supplier.dart';
import '../../services/branch_service.dart';
import '../../services/customer_service.dart';
import '../../services/report_export_service.dart';
import '../../services/supplier_service.dart';
import '../../utils/branch_filter.dart';

const _kBlue = Color(0xFF2F6FED);

/// A customer or supplier, unified into one row shape for the table.
class _PartyRow {
  final String name;
  final String type; // 'Customer' or 'Supplier'
  final String contact;
  final String address;
  final String area;
  final double balance;

  const _PartyRow({
    required this.name,
    required this.type,
    required this.contact,
    required this.address,
    required this.area,
    required this.balance,
  });
}

class PartiesReportScreen extends StatefulWidget {
  const PartiesReportScreen({super.key});

  @override
  State<PartiesReportScreen> createState() => _PartiesReportScreenState();
}

class _PartiesReportScreenState extends State<PartiesReportScreen> {
  final CustomerService _customerService = CustomerService();
  final SupplierService _supplierService = SupplierService();
  final BranchService _branchService = BranchService();

  final _searchController = TextEditingController();
  String _search = '';
  String _type = 'Customer'; // 'Customer' or 'Supplier'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchId, _) {
        return StreamBuilder<List<Branch>>(
          stream: _branchService.streamBranches(),
          builder: (context, branchSnapshot) {
            final branches = branchSnapshot.data ?? [];
            final matches = branches.where((b) => b.id == branchId);
            final branch = matches.isNotEmpty ? matches.first : null;

            return StreamBuilder<List<Customer>>(
              stream: _customerService.streamCustomers(),
              builder: (context, customerSnapshot) {
                final customers = customerSnapshot.data ?? [];

                return StreamBuilder<List<Supplier>>(
                  stream: _supplierService.streamSuppliers(),
                  builder: (context, supplierSnapshot) {
                    final suppliers = supplierSnapshot.data ?? [];

                    var rows = _type == 'Customer'
                        ? customers
                        .where((c) =>
                    branchId == null || c.branchId == branchId)
                        .map((c) => _PartyRow(
                      name: c.name,
                      type: 'Customer',
                      contact: c.phone,
                      address: c.address,
                      area: c.area,
                      balance: c.totalReceivable,
                    ))
                        .toList()
                        : suppliers
                        .where((s) =>
                    branchId == null || s.branchId == branchId)
                        .map((s) => _PartyRow(
                      name: s.name,
                      type: 'Supplier',
                      contact: s.phone,
                      address: s.address,
                      area: s.area,
                      balance: s.totalPayable,
                    ))
                        .toList();

                    if (_search.isNotEmpty) {
                      rows = rows
                          .where((r) =>
                          r.name.toLowerCase().contains(_search))
                          .toList();
                    }
                    rows.sort((a, b) => a.name.compareTo(b.name));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBranchHeader(branch),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            _type == 'Customer'
                                ? 'Customer List'
                                : 'Supplier List',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _kBlue),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFilters(rows),
                        const SizedBox(height: 16),
                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                'No parties match these filters.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          _buildTable(rows),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBranchHeader(Branch? branch) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFEDF1FB),
            backgroundImage: (branch?.logoUrl.isNotEmpty ?? false)
                ? NetworkImage(branch!.logoUrl)
                : null,
            child: (branch?.logoUrl.isEmpty ?? true)
                ? const Icon(Icons.apartment, color: _kBlue)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch?.name ?? 'All Branches',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _kBlue),
                ),
                if ((branch?.address ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [
                        branch!.address,
                        if (branch.contact.isNotEmpty) branch.contact,
                      ].join(', '),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(List<_PartyRow> rows) {
    final typeDropdown = SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        value: _type,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        items: const [
          DropdownMenuItem(value: 'Customer', child: Text('Customer')),
          DropdownMenuItem(value: 'Supplier', child: Text('Supplier')),
        ],
        onChanged: (v) => setState(() => _type = v ?? 'Customer'),
      ),
    );

    final search = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
      decoration: InputDecoration(
        hintText: 'Search...',
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );

    final printButton = OutlinedButton.icon(
      onPressed: () => _handlePrint(rows),
      icon: const Icon(Icons.print_outlined, size: 16),
      label: const Text('Print'),
    );

    final excelButton = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E8E4F),
        foregroundColor: Colors.white,
      ),
      onPressed: () => _handleExcelExport(rows),
      icon: const Icon(Icons.grid_on, size: 16),
      label: const Text('Excel'),
    );

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 700;
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            typeDropdown,
            const SizedBox(height: 10),
            search,
            const SizedBox(height: 10),
            Row(
              children: [
                printButton,
                const SizedBox(width: 10),
                excelButton,
              ],
            ),
          ],
        );
      }
      return Row(
        children: [
          typeDropdown,
          const SizedBox(width: 12),
          Expanded(child: search),
          const SizedBox(width: 12),
          printButton,
          const SizedBox(width: 10),
          excelButton,
        ],
      );
    });
  }

  Widget _buildTable(List<_PartyRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMinHeight: 52,
          dataRowMaxHeight: 60,
          headingRowColor: MaterialStateProperty.all(_kBlue),
          columns: const [
            DataColumn(label: Text('Sr', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('Name', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('Type', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('Contact', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('Address', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('Area', style: TextStyle(color: Colors.white))),
            DataColumn(
                label: Text('Balance', style: TextStyle(color: Colors.white)),
                numeric: true),
          ],
          rows: List.generate(rows.length, (i) {
            final row = rows[i];
            return DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(row.name,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(row.type)),
              DataCell(Text(row.contact.isEmpty ? '-' : row.contact)),
              DataCell(Text(row.address.isEmpty ? '-' : row.address)),
              DataCell(Text(row.area.isEmpty ? '-' : row.area)),
              DataCell(Text(
                row.balance.toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: row.balance > 0 ? Colors.red : Colors.grey,
                ),
              )),
            ]);
          }),
        ),
      ),
    );
  }

  ReportData _buildReportData(List<_PartyRow> rows) {
    final total = rows.fold<double>(0, (s, r) => s + r.balance);
    return ReportData(
      title: '$_type List',
      subtitle: 'Branch: ${selectedBranchName.value ?? 'All Branches'} - '
          '${rows.length} ${_type.toLowerCase()}s',
      columns: const ['Sr', 'Name', 'Type', 'Contact', 'Address', 'Area', 'Balance'],
      columnFlex: const [0.6, 2, 1.2, 1.6, 2.2, 1.4, 1.4],
      numericColumns: const {6},
      sections: [
        ReportSection(
          title: '$_type List',
          rows: [
            for (var i = 0; i < rows.length; i++)
              [
                '${i + 1}',
                rows[i].name,
                rows[i].type,
                rows[i].contact.isEmpty ? '-' : rows[i].contact,
                rows[i].address.isEmpty ? '-' : rows[i].address,
                rows[i].area.isEmpty ? '-' : rows[i].area,
                rows[i].balance.toStringAsFixed(2),
              ],
          ],
          totalRow: ['', '', '', '', '', 'Total', total.toStringAsFixed(2)],
        ),
      ],
      overallRow: [
        'Total ${_type}s: ${rows.length}',
        'Total Balance: ${total.toStringAsFixed(2)}',
      ],
    );
  }

  Future<void> _handlePrint(List<_PartyRow> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No parties to print.')),
      );
      return;
    }
    try {
      await ReportExportService.printReport(_buildReportData(rows),
          fileName: 'parties_report');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open print preview: $e')),
      );
    }
  }

  Future<void> _handleExcelExport(List<_PartyRow> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No parties to export.')),
      );
      return;
    }
    try {
      await ReportExportService.exportExcel(
          _buildReportData(rows), 'parties_report');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel file saved: parties_report.xlsx')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export Excel: $e')),
      );
    }
  }
}