import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../models/customer.dart';
import '../../models/supplier.dart';
import '../../services/branch_service.dart';
import '../../services/customer_service.dart';
import '../../services/report_export_service.dart';
import '../../services/supplier_service.dart';
import '../../utils/branch_filter.dart';

// Colours taken from the reference "Customer List" page.
class _C {
  static const blue = Color(0xFF0D6EFD);
  static const line = Color(0xFFDEE2E6);
  static const btnBg = Color(0xFFEFEFEF);
  static const btnBorder = Color(0xFF767676);
  static const green = Color(0xFF198754);
}

// One line of the report (either a customer or a supplier).
class _Party {
  final String name;
  final String type; // 'Customer' / 'Supplier'
  final String contact;
  final String address;
  final String area;
  final double balance;

  const _Party(this.name, this.type, this.contact, this.address, this.area,
      this.balance);
}

class PartiesReportScreen extends StatefulWidget {
  const PartiesReportScreen({super.key});

  @override
  State<PartiesReportScreen> createState() => _PartiesReportScreenState();
}

class _PartiesReportScreenState extends State<PartiesReportScreen> {
  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
  List<Branch> _branches = [];
  final List<StreamSubscription> _subs = [];

  final TextEditingController _search = TextEditingController();
  String _type = 'Customer'; // Customer / Supplier / All

  @override
  void initState() {
    super.initState();

    void listen<T>(Stream<T> stream, void Function(T) assign) {
      _subs.add(stream.listen((d) {
        if (!mounted) return;
        setState(() => assign(d));
      }, onError: (_) {}));
    }

    listen(CustomerService().streamCustomers(), (d) => _customers = d);
    listen(SupplierService().streamSuppliers(), (d) => _suppliers = d);
    listen(BranchService().streamBranches(), (d) => _branches = d);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _search.dispose();
    super.dispose();
  }

  // ================= DATA =================

  String _money(double v) {
    final neg = v < 0;
    final parts = v.abs().toStringAsFixed(2).split('.');
    final digits = parts[0];
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
      b.write(digits[i]);
    }
    return '${neg ? '-' : ''}$b.${parts[1]}';
  }

  List<_Party> _parties(String? branchId) {
    final q = _search.text.trim().toLowerCase();
    final out = <_Party>[];

    bool matches(String name, String phone, String address, String area) {
      if (q.isEmpty) return true;
      return name.toLowerCase().contains(q) ||
          phone.toLowerCase().contains(q) ||
          address.toLowerCase().contains(q) ||
          area.toLowerCase().contains(q);
    }

    if (_type == 'Customer' || _type == 'All') {
      final list = _customers
          .where((c) => branchId == null || c.branchId == branchId)
          .where((c) => matches(c.name, c.phone, c.address, c.area))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final c in list) {
        out.add(_Party(
            c.name, 'Customer', c.phone, c.address, c.area, c.totalReceivable));
      }
    }

    if (_type == 'Supplier' || _type == 'All') {
      final list = _suppliers
          .where((s) => branchId == null || s.branchId == branchId)
          .where((s) => matches(s.name, s.phone, s.address, s.area))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final s in list) {
        out.add(_Party(
            s.name, 'Supplier', s.phone, s.address, s.area, s.totalPayable));
      }
    }

    return out;
  }

  Branch? _branchById(String? id) {
    if (id == null) return null;
    for (final b in _branches) {
      if (b.id == id) return b;
    }
    return null;
  }

  String get _title {
    switch (_type) {
      case 'Supplier':
        return 'Supplier List';
      case 'All':
        return 'Parties List';
      default:
        return 'Customer List';
    }
  }

  // ================= EXPORT =================

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: color, content: Text(msg)),
    );
  }

  ReportData _reportData(List<_Party> rows, String branchLabel) {
    List<String> line(int i, _Party p) => [
      '${i + 1}',
      p.name,
      p.type,
      p.contact.isEmpty ? '-' : p.contact,
      p.address.isEmpty ? '-' : p.address,
      p.area.isEmpty ? '-' : p.area,
      p.balance.toStringAsFixed(2),
    ];

    final types = <String>[];
    for (final r in rows) {
      if (!types.contains(r.type)) types.add(r.type);
    }

    final sections = <ReportSection>[];
    for (final t in types) {
      final list = rows.where((r) => r.type == t).toList();
      sections.add(ReportSection(
        title: t == 'Customer' ? 'Customers (Receivable)' : 'Suppliers (Payable)',
        rows: [for (var i = 0; i < list.length; i++) line(i, list[i])],
        totalRow: [
          '',
          'Total',
          '',
          '',
          '',
          '',
          list.fold(0.0, (s, p) => s + p.balance).toStringAsFixed(2),
        ],
      ));
    }

    return ReportData(
      title: _title,
      subtitle: 'Branch: $branchLabel',
      columns: const [
        'Sr',
        'Name',
        'Type',
        'Contact',
        'Address',
        'Area',
        'Balance',
      ],
      columnFlex: const [0.6, 2.2, 1.3, 1.8, 2.6, 1.4, 1.5],
      numericColumns: const {6},
      sections: sections,
      overallRow: [
        'Total Parties: ${rows.length}',
        'Total Balance: ${rows.fold(0.0, (s, p) => s + p.balance).toStringAsFixed(2)}',
      ],
    );
  }

  Future<void> _print(List<_Party> rows, String branchLabel) async {
    if (rows.isEmpty) {
      _snack('No records to print.');
      return;
    }
    try {
      await ReportExportService.printReport(
        _reportData(rows, branchLabel),
        fileName: 'parties_report',
      );
    } catch (e) {
      if (mounted) _snack('Could not open print preview: $e');
    }
  }

  Future<void> _excel(List<_Party> rows, String branchLabel) async {
    if (rows.isEmpty) {
      _snack('No records to export.');
      return;
    }
    try {
      await ReportExportService.exportExcel(
          _reportData(rows, branchLabel), 'parties_report');
      if (mounted) _snack('Excel file saved.', color: _C.green);
    } catch (e) {
      if (mounted) _snack('Could not export Excel: $e');
    }
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever the branch picked in the top bar changes.
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchId, _) {
        final rows = _parties(branchId);
        final branch = _branchById(branchId);
        final branchLabel = selectedBranchName.value ?? 'All Branches';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x0F000000), blurRadius: 8)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(branch, branchLabel),
              const SizedBox(height: 10),
              Container(height: 3, color: _C.blue),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _title,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _C.blue),
                ),
              ),
              const SizedBox(height: 14),
              _toolbar(rows, branchLabel),
              const SizedBox(height: 14),
              _table(rows),
            ],
          ),
        );
      },
    );
  }

  // ---------- branch letterhead ----------

  Widget _header(Branch? branch, String branchLabel) {
    final address = branch == null
        ? ''
        : (branch.address.isNotEmpty
        ? branch.address
        : [branch.area, branch.city].where((s) => s.isNotEmpty).join(', '));
    final contact = branch?.contact ?? '';
    final logo = branch?.logoUrl ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 76,
          height: 76,
          child: logo.isEmpty
              ? const Icon(Icons.apartment_rounded, size: 56, color: _C.blue)
              : Image.network(
            logo,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.apartment_rounded,
                size: 56,
                color: _C.blue),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(branchLabel,
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: _C.blue)),
              if (address.isNotEmpty)
                Text(address,
                    style: const TextStyle(fontSize: 16, color: Colors.black87)),
              if (contact.isNotEmpty)
                Text(contact,
                    style: const TextStyle(fontSize: 16, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- dropdown + search + Print + Excel ----------

  Widget _btn(IconData icon, Color iconColor, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _C.btnBg,
          border: Border.all(color: _C.btnBorder),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 15, color: Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(List<_Party> rows, String branchLabel) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black87),
            borderRadius: BorderRadius.circular(3),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _type,
              isDense: true,
              items: const [
                DropdownMenuItem(value: 'Customer', child: Text('Customer')),
                DropdownMenuItem(value: 'Supplier', child: Text('Supplier')),
                DropdownMenuItem(value: 'All', child: Text('All')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
          ),
        ),
        SizedBox(
          width: 250,
          height: 38,
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search...',
              isDense: true,
              contentPadding:
              EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(3)),
                borderSide: BorderSide(color: Colors.black87),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(3)),
                borderSide: BorderSide(color: Colors.black87),
              ),
            ),
          ),
        ),
        _btn(Icons.print_outlined, Colors.black87, 'Print',
                () => _print(rows, branchLabel)),
        _btn(Icons.table_view, _C.green, 'Excel',
                () => _excel(rows, branchLabel)),
      ],
    );
  }

  // ---------- table ----------

  Widget _cell(String text,
      {required int flex, bool header = false, bool bold = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
                color: header ? Colors.transparent : _C.line, width: 1),
            bottom: const BorderSide(color: _C.line),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: header ? 17 : 15,
            fontWeight: (header || bold) ? FontWeight.w700 : FontWeight.w400,
            color: header ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _table(List<_Party> rows) {
    final total = rows.fold<double>(0, (s, p) => s + p.balance);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth < 860 ? 860.0 : c.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: w,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: _C.line)),
              child: Column(
                children: [
                  Container(
                    color: _C.blue,
                    child: Row(
                      children: [
                        _cell('Sr', flex: 6, header: true),
                        _cell('Name', flex: 20, header: true),
                        _cell('Type', flex: 14, header: true),
                        _cell('Contact', flex: 18, header: true),
                        _cell('Address', flex: 24, header: true),
                        _cell('Area', flex: 14, header: true),
                        _cell('Balance', flex: 14, header: true),
                      ],
                    ),
                  ),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 26),
                      child: Text('No records found.',
                          style: TextStyle(fontSize: 16)),
                    ),
                  for (var i = 0; i < rows.length; i++)
                    Row(
                      children: [
                        _cell('${i + 1}', flex: 6),
                        _cell(rows[i].name, flex: 20),
                        _cell(rows[i].type, flex: 14),
                        _cell(rows[i].contact, flex: 18),
                        _cell(rows[i].address, flex: 24),
                        _cell(rows[i].area, flex: 14),
                        _cell(_money(rows[i].balance), flex: 14),
                      ],
                    ),
                  if (rows.isNotEmpty)
                    Container(
                      color: const Color(0xFFF8F9FA),
                      child: Row(
                        children: [
                          _cell('', flex: 6),
                          _cell('Total', flex: 20, bold: true),
                          _cell('', flex: 14),
                          _cell('', flex: 18),
                          _cell('', flex: 24),
                          _cell('', flex: 14),
                          _cell(_money(total), flex: 14, bold: true),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}