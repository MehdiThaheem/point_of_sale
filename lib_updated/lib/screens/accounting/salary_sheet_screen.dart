import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../models/employee.dart';
import '../../models/salary_payment.dart';
import '../../services/branch_service.dart';
import '../../services/employee_service.dart';
import '../../services/report_export_service.dart';
import '../../services/salary_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/confirm_dialog.dart';

// Colours taken from the reference Salary Sheet.
class _C {
  static const title = Color(0xFF0B3D91); // SALARY SHEET + table header
  static const blue = Color(0xFF0D6EFD); // filter button
  static const green = Color(0xFF198754); // excel button / paid
  static const dark = Color(0xFF212529); // print button
  static const red = Color(0xFFDC3545);
  static const orange = Color(0xFFE67E00);
  static const line = Color(0xFFDEE2E6);
  static const tint = Color(0xFFEAF1FB);
  static const grey = Color(0xFF6C757D);
}

const List<String> _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _n(double v) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b';
}

// One staff member's line on the sheet for the chosen month.
class _SheetRow {
  final Employee employee;
  final String branchName;
  final double basic;
  final double deduction;
  final String reason;
  final double incentive;
  final double paid;
  final List<SalaryPayment> payments;

  _SheetRow({
    required this.employee,
    required this.branchName,
    required this.basic,
    required this.deduction,
    required this.reason,
    required this.incentive,
    required this.paid,
    required this.payments,
  });

  double get gross => basic + incentive - deduction;
  double get remaining => math.max(0, gross - paid);

  String get status {
    if (paid > 0 && paid >= gross - 0.5) return 'Paid';
    if (paid > 0) return 'Partial';
    return 'Unpaid';
  }
}

class SalarySheetScreen extends StatefulWidget {
  const SalarySheetScreen({super.key});

  @override
  State<SalarySheetScreen> createState() => _SalarySheetScreenState();
}

class _SalarySheetScreenState extends State<SalarySheetScreen> {
  final SalaryService _salaryService = SalaryService();

  List<Employee> _employees = [];
  List<SalaryPayment> _payments = [];
  List<Branch> _branches = [];
  final List<StreamSubscription> _subs = [];

  final TextEditingController _search = TextEditingController();

  // Month/year being edited vs. the one applied with the filter button.
  late int _pendingMonth;
  late int _pendingYear;
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _pendingMonth = _month = now.month;
    _pendingYear = _year = now.year;

    void listen<T>(Stream<T> stream, void Function(T) assign) {
      _subs.add(stream.listen((d) {
        if (!mounted) return;
        setState(() => assign(d));
      }, onError: (_) {}));
    }

    listen(EmployeeService().streamEmployees(), (d) => _employees = d);
    listen(_salaryService.streamSalaryPayments(), (d) => _payments = d);
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

  String get _monthLabel => '${_monthNames[_month - 1]} $_year';

  List<_SheetRow> _rows(String? branchId) {
    final q = _search.text.trim().toLowerCase();

    final byEmployee = <String, List<SalaryPayment>>{};
    for (final p in _payments) {
      if (p.month == _monthLabel) {
        byEmployee.putIfAbsent(p.employeeId, () => []).add(p);
      }
    }

    final out = <_SheetRow>[];
    for (final e in _employees) {
      if (branchId != null && e.branchId != branchId) continue;

      final pays = byEmployee[e.id] ?? const <SalaryPayment>[];
      if (e.status != 'active' && pays.isEmpty) continue;
      if (q.isNotEmpty && !e.name.toLowerCase().contains(q)) continue;

      final recordedBasic = pays.fold<double>(0, (m, p) => math.max(m, p.basic));
      final reasons = pays
          .map((p) => p.deductionReason.trim())
          .where((r) => r.isNotEmpty)
          .join(', ');

      out.add(_SheetRow(
        employee: e,
        branchName: e.branchName.isEmpty ? 'Unassigned' : e.branchName,
        basic: recordedBasic > 0 ? recordedBasic : e.salary,
        deduction: pays.fold<double>(0, (s, p) => s + p.deduction),
        reason: reasons,
        incentive: pays.fold<double>(0, (s, p) => s + p.incentive),
        paid: pays.fold<double>(0, (s, p) => s + p.amount),
        payments: pays,
      ));
    }

    out.sort((a, b) {
      final c = a.branchName.compareTo(b.branchName);
      return c != 0 ? c : a.employee.name.compareTo(b.employee.name);
    });
    return out;
  }

  Branch? _branchById(String? id) {
    if (id == null) return null;
    for (final b in _branches) {
      if (b.id == id) return b;
    }
    return null;
  }

  // ================= ACTIONS =================

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: color, content: Text(msg)),
    );
  }

  String _deductionText(_SheetRow r) {
    if (r.deduction <= 0) return '0';
    return r.reason.isEmpty
        ? _n(r.deduction)
        : '${_n(r.deduction)} (${r.reason})';
  }

  Map<String, List<_SheetRow>> _groups(List<_SheetRow> rows) {
    final map = <String, List<_SheetRow>>{};
    for (final r in rows) {
      map.putIfAbsent(r.branchName, () => []).add(r);
    }
    return map;
  }

  ReportData _reportData(List<_SheetRow> rows, String branchLabel) {
    List<String> line(int i, _SheetRow r) => [
      '${i + 1}',
      r.employee.name,
      _n(r.basic),
      _deductionText(r),
      _n(r.incentive),
      _n(r.gross),
      _n(r.paid),
      r.status,
    ];

    List<String> totals(List<_SheetRow> list) => [
      '',
      'Total',
      _n(list.fold(0.0, (s, r) => s + r.basic)),
      _n(list.fold(0.0, (s, r) => s + r.deduction)),
      _n(list.fold(0.0, (s, r) => s + r.incentive)),
      _n(list.fold(0.0, (s, r) => s + r.gross)),
      _n(list.fold(0.0, (s, r) => s + r.paid)),
      '',
    ];

    final groups = _groups(rows);
    return ReportData(
      title: 'Salary Sheet',
      subtitle: '$branchLabel - For: $_monthLabel',
      columns: const [
        'Sr#',
        'Name',
        'Basic',
        'Deduction (Reason)',
        'Incentive',
        'Gross',
        'Paid',
        'Status',
      ],
      columnFlex: const [0.7, 2.6, 1.4, 2.8, 1.4, 1.4, 1.4, 1.4],
      numericColumns: const {2, 4, 5, 6},
      sections: [
        for (final entry in groups.entries)
          ReportSection(
            title: entry.key,
            rows: [
              for (var i = 0; i < entry.value.length; i++)
                line(i, entry.value[i]),
            ],
            totalRow: totals(entry.value),
          ),
      ],
      overallRow: [
        'Staff: ${rows.length}',
        'Gross: ${_n(rows.fold(0.0, (s, r) => s + r.gross))}',
        'Paid: ${_n(rows.fold(0.0, (s, r) => s + r.paid))}',
      ],
    );
  }

  Future<void> _print(List<_SheetRow> rows, String branchLabel) async {
    if (rows.isEmpty) {
      _snack('No records to print.');
      return;
    }
    try {
      await ReportExportService.printReport(
        _reportData(rows, branchLabel),
        fileName: 'salary_sheet_${_monthNames[_month - 1]}_$_year',
      );
    } catch (e) {
      if (mounted) _snack('Could not open print preview: $e');
    }
  }

  Future<void> _excel(List<_SheetRow> rows, String branchLabel) async {
    if (rows.isEmpty) {
      _snack('No records to export.');
      return;
    }
    try {
      await ReportExportService.exportExcel(
        _reportData(rows, branchLabel),
        'salary_sheet_${_monthNames[_month - 1]}_$_year',
      );
      if (mounted) _snack('Excel file saved.', color: _C.green);
    } catch (e) {
      if (mounted) _snack('Could not export Excel: $e');
    }
  }

  Future<void> _deleteRecords(_SheetRow r) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Salary Record',
      message:
      'Remove the salary payment for "${r.employee.name}" ($_monthLabel)?',
    );
    if (!ok) return;
    try {
      for (final p in r.payments) {
        await _salaryService.deleteSalaryPayment(p.id);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  // Pay / generate the salary of one staff member for the chosen month.
  // The dialog owns its own controllers and just returns the values; the
  // saving happens here, after the dialog is fully closed.
  Future<void> _pay(_SheetRow r) async {
    final res = await showDialog<_PayResult>(
      context: context,
      builder: (_) => _PaySalaryDialog(row: r, monthLabel: _monthLabel),
    );
    if (res == null || !mounted) return;

    try {
      await _salaryService.generateSalary(SalaryPayment(
        id: '',
        employeeId: r.employee.id,
        employeeName: r.employee.name,
        month: _monthLabel,
        amount: res.pay,
        basic: res.basic,
        deduction: res.deduction,
        deductionReason: res.reason,
        incentive: res.incentive,
      ));
      if (mounted) {
        _snack('Salary saved for ${r.employee.name}.', color: _C.green);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever the branch picked in the top bar changes.
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchId, _) {
        final rows = _rows(branchId);
        final branch = _branchById(branchId);
        final branchLabel = selectedBranchName.value ?? 'All Branches';

        final compact = MediaQuery.of(context).size.width < 600;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 16 : 26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 12)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(branch, branchLabel),
              const SizedBox(height: 14),
              Container(height: 3, color: _C.title),
              const SizedBox(height: 22),
              _toolbar(rows, branchLabel),
              const SizedBox(height: 18),
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

    final left = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: logo.isEmpty
              ? const Icon(Icons.apartment_rounded, size: 52, color: _C.title)
              : Image.network(
            logo,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.apartment_rounded,
                size: 52,
                color: _C.title),
          ),
        ),
        const SizedBox(width: 18),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(branchLabel,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87)),
              if (address.isNotEmpty)
                Text(address,
                    style: const TextStyle(fontSize: 14, color: _C.grey)),
              if (contact.isNotEmpty)
                Text('Contact: $contact',
                    style: const TextStyle(fontSize: 14, color: _C.grey)),
            ],
          ),
        ),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('SALARY SHEET',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, color: _C.title)),
        const SizedBox(height: 2),
        Text('For: $_monthLabel',
            style: const TextStyle(fontSize: 16, color: Colors.black87)),
      ],
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 620) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [left, const SizedBox(height: 12), right],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: left), right],
      );
    });
  }

  // ---------- search + month/year + buttons ----------

  Widget _iconBtn(IconData icon, Color color, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _toolbar(List<_SheetRow> rows, String branchLabel) {
    final now = DateTime.now().year;
    final years = [for (var y = now - 4; y <= now + 1; y++) y];

    // Everything here wraps onto a new line when the screen is narrow, so
    // nothing can overflow on a phone.
    return LayoutBuilder(builder: (context, c) {
      final searchWidth = c.maxWidth < 320 ? c.maxWidth : 320.0;
      return Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: searchWidth,
            height: 42,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search staff...',
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                isDense: true,
              ),
            ),
          ),
          Container(
            constraints: BoxConstraints(maxWidth: c.maxWidth),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: _C.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pendingMonth,
                    items: [
                      for (var i = 1; i <= 12; i++)
                        DropdownMenuItem(
                            value: i, child: Text(_monthNames[i - 1])),
                    ],
                    onChanged: (v) =>
                        setState(() => _pendingMonth = v ?? _pendingMonth),
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pendingYear,
                    items: [
                      for (final y in years)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (v) =>
                        setState(() => _pendingYear = v ?? _pendingYear),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconBtn(Icons.filter_alt, _C.blue, 'Apply filter', () {
                      setState(() {
                        _month = _pendingMonth;
                        _year = _pendingYear;
                      });
                    }),
                    const SizedBox(width: 6),
                    _iconBtn(Icons.table_view, _C.green, 'Export Excel',
                            () => _excel(rows, branchLabel)),
                    const SizedBox(width: 6),
                    _iconBtn(Icons.print, _C.dark, 'Print',
                            () => _print(rows, branchLabel)),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  // ---------- table ----------

  Widget _cell(String text,
      {required int flex,
        bool header = false,
        bool bold = false,
        bool center = true,
        Color? color,
        Widget? child}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        alignment: center ? Alignment.center : Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
                color: header ? Colors.white24 : _C.line, width: 1),
            bottom: const BorderSide(color: _C.line),
          ),
        ),
        child: child ??
            Text(
              text,
              textAlign: center ? TextAlign.center : TextAlign.left,
              style: TextStyle(
                fontSize: header ? 15 : 14,
                fontWeight:
                (header || bold) ? FontWeight.w800 : FontWeight.w400,
                color: header ? Colors.white : (color ?? Colors.black87),
              ),
            ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'Paid'
        ? _C.green
        : (status == 'Partial' ? _C.orange : _C.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _actionCell(_SheetRow r) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (r.status != 'Paid')
          InkWell(
            onTap: () => _pay(r),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _C.blue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Pay',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
        if (r.payments.isNotEmpty)
          IconButton(
            tooltip: 'Delete record',
            onPressed: () => _deleteRecords(r),
            icon: const Icon(Icons.delete_outline, color: _C.red, size: 20),
          ),
      ],
    );
  }

  Widget _table(List<_SheetRow> rows) {
    final groups = _groups(rows);
    final showBands = selectedBranchId.value == null;

    double sum(double Function(_SheetRow) f) =>
        rows.fold(0.0, (s, r) => s + f(r));

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth < 950 ? 950.0 : c.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: w,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _C.line),
              ),
              child: Column(
                children: [
                  Container(
                    color: _C.title,
                    child: Row(
                      children: [
                        _cell('Sr#', flex: 6, header: true),
                        _cell('Name', flex: 18, header: true),
                        _cell('Basic', flex: 11, header: true),
                        _cell('Deduction (Reason)', flex: 20, header: true),
                        _cell('Incentive', flex: 11, header: true),
                        _cell('Gross', flex: 11, header: true),
                        _cell('Paid', flex: 11, header: true),
                        _cell('Status', flex: 11, header: true),
                        _cell('Action', flex: 14, header: true),
                      ],
                    ),
                  ),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 26),
                      child: Text('No records found.',
                          style: TextStyle(fontSize: 16)),
                    ),
                  for (final entry in groups.entries) ...[
                    if (showBands)
                      Container(
                        width: double.infinity,
                        color: _C.tint,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Text(entry.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _C.title)),
                      ),
                    for (var i = 0; i < entry.value.length; i++)
                      Row(
                        children: [
                          _cell('${i + 1}', flex: 6),
                          _cell(entry.value[i].employee.name,
                              flex: 18, center: false),
                          _cell(_n(entry.value[i].basic), flex: 11),
                          _cell(_deductionText(entry.value[i]), flex: 20),
                          _cell(_n(entry.value[i].incentive), flex: 11),
                          _cell(_n(entry.value[i].gross),
                              flex: 11, bold: true),
                          _cell(_n(entry.value[i].paid), flex: 11),
                          _cell('',
                              flex: 11,
                              child: _statusChip(entry.value[i].status)),
                          _cell('',
                              flex: 14, child: _actionCell(entry.value[i])),
                        ],
                      ),
                  ],
                  if (rows.isNotEmpty)
                    Container(
                      color: const Color(0xFFF8F9FA),
                      child: Row(
                        children: [
                          _cell('', flex: 6),
                          _cell('Total', flex: 18, bold: true, center: false),
                          _cell(_n(sum((r) => r.basic)), flex: 11, bold: true),
                          _cell(_n(sum((r) => r.deduction)),
                              flex: 20, bold: true),
                          _cell(_n(sum((r) => r.incentive)),
                              flex: 11, bold: true),
                          _cell(_n(sum((r) => r.gross)), flex: 11, bold: true),
                          _cell(_n(sum((r) => r.paid)), flex: 11, bold: true),
                          _cell('', flex: 11),
                          _cell('', flex: 14),
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


class _PayResult {
  final double basic;
  final double deduction;
  final String reason;
  final double incentive;
  final double pay;
  const _PayResult(
      this.basic, this.deduction, this.reason, this.incentive, this.pay);
}

class _PaySalaryDialog extends StatefulWidget {
  final _SheetRow row;
  final String monthLabel;
  const _PaySalaryDialog({required this.row, required this.monthLabel});

  @override
  State<_PaySalaryDialog> createState() => _PaySalaryDialogState();
}

class _PaySalaryDialogState extends State<_PaySalaryDialog> {
  late final TextEditingController _basic;
  late final TextEditingController _ded;
  late final TextEditingController _reason;
  late final TextEditingController _inc;
  late final TextEditingController _paid;
  bool _paidEdited = false;
  String? _error;

  bool get _first => widget.row.payments.isEmpty;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    _basic = TextEditingController(text: r.basic.toStringAsFixed(0));
    _ded = TextEditingController();
    _reason = TextEditingController();
    _inc = TextEditingController();
    _paid = TextEditingController(
        text: (_first ? r.basic : r.remaining).toStringAsFixed(0));
  }

  @override
  void dispose() {
    _basic.dispose();
    _ded.dispose();
    _reason.dispose();
    _inc.dispose();
    _paid.dispose();
    super.dispose();
  }

  double _v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  double get _gross => _v(_basic) + _v(_inc) - _v(_ded);

  void _recalc() {
    setState(() {
      if (!_paidEdited && _first) {
        _paid.text = math.max(0, _gross).toStringAsFixed(0);
      }
    });
  }

  void _submit() {
    final pay = _v(_paid);
    if (pay <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    Navigator.of(context).pop(_PayResult(
      _first ? _v(_basic) : 0,
      _first ? _v(_ded) : 0,
      _first ? _reason.text.trim() : '',
      _first ? _v(_inc) : 0,
      pay,
    ));
  }

  Widget _box(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _C.tint,
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    return AlertDialog(
      title: Text('${r.employee.name} — ${widget.monthLabel}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_first) ...[
                TextField(
                  controller: _basic,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalc(),
                  decoration: const InputDecoration(labelText: 'Basic'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ded,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalc(),
                  decoration: const InputDecoration(labelText: 'Deduction'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reason,
                  decoration:
                  const InputDecoration(labelText: 'Deduction Reason'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _inc,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalc(),
                  decoration: const InputDecoration(labelText: 'Incentive'),
                ),
                const SizedBox(height: 12),
                _box(Text('Gross: ${_n(_gross)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16))),
              ] else
                _box(Text(
                    'Gross: ${_n(r.gross)}   ·   Paid: ${_n(r.paid)}   ·   Remaining: ${_n(r.remaining)}',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 12),
              TextField(
                controller: _paid,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {
                  _paidEdited = true;
                  _error = null;
                }),
                decoration: InputDecoration(
                    labelText: 'Pay Now', errorText: _error),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}