import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/employee.dart';
import '../../models/expense.dart';
import '../../models/expense_head.dart';
import '../../models/product.dart';
import '../../models/raw_material.dart';
import '../../models/salary_payment.dart';
import '../../models/sales.dart';
import '../../models/supplier.dart';
import '../../services/customer_service.dart';
import '../../services/employee_service.dart';
import '../../services/expense_head_service.dart';
import '../../services/expense_service.dart';
import '../../services/product_service.dart';
import '../../services/raw_material_service.dart';
import '../../services/sale_service.dart';
import '../../services/salary_service.dart';
import '../../services/supplier_service.dart';
import '../../utils/balance_sheet_pdf.dart';
import '../../utils/branch_filter.dart';

class _Palette {
  static const blue = Color(0xFF0D6EFD);
  static const dark = Color(0xFF343A40);
  static const filterBg = Color(0xFFE9ECEF);
  static const line = Color(0xFFDEE2E6);
}

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  // Latest snapshot of every source collection. Kept as plain fields
  // (filled by the subscriptions below) instead of nesting nine
  // StreamBuilders on top of each other.
  List<Product> _products = [];
  List<RawMaterial> _rawMaterials = [];
  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
  List<Sale> _sales = [];
  List<Expense> _expenses = [];
  List<ExpenseHead> _heads = [];
  List<SalaryPayment> _salaryPayments = [];
  List<Employee> _employees = [];
  final List<StreamSubscription> _subs = [];

  // The date range being edited vs. the one actually applied — the
  // sheet only recalculates when "Apply Filter" is pressed.
  late DateTime _pendingFrom;
  late DateTime _pendingTo;
  late DateTime _from;
  late DateTime _to;

  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _pendingFrom = DateTime(now.year, 1, 1);
    _pendingTo = DateTime(now.year, now.month, now.day);
    _from = _pendingFrom;
    _to = _pendingTo;

    void listen<T>(Stream<T> stream, void Function(T) assign) {
      _subs.add(stream.listen((data) {
        if (!mounted) return;
        setState(() => assign(data));
      }));
    }

    listen(ProductService().streamProducts(), (d) => _products = d);
    listen(RawMaterialService().streamRawMaterials(), (d) => _rawMaterials = d);
    listen(CustomerService().streamCustomers(), (d) => _customers = d);
    listen(SupplierService().streamSuppliers(), (d) => _suppliers = d);
    listen(SaleService().streamSales(), (d) => _sales = d);
    listen(ExpenseService().streamExpenses(), (d) => _expenses = d);
    listen(ExpenseHeadService().streamExpenseHeads(), (d) => _heads = d);
    listen(SalaryService().streamSalaryPayments(), (d) => _salaryPayments = d);
    listen(EmployeeService().streamEmployees(), (d) => _employees = d);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  String _fmtAmount(double v) => v.toStringAsFixed(2);

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _pendingFrom : _pendingTo,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _pendingFrom = picked;
      } else {
        _pendingTo = picked;
      }
    });
  }

  // ================= THE NUMBERS =================

  // Returns (assets, liabilities&equity) for the current branch + date
  // range. Balances that can't be "rewound" (stock, receivable, payable)
  // are as of today; everything transaction-based respects the range.
  ({List<SheetLine> assets, List<SheetLine> liabilities}) _compute() {
    final branchId = selectedBranchId.value;
    final start = DateTime(_from.year, _from.month, _from.day);
    final end = DateTime(_to.year, _to.month, _to.day, 23, 59, 59);

    bool branchOk(String id) => branchId == null || id == branchId;
    bool inRange(DateTime? d) =>
        d == null || (!d.isBefore(start) && !d.isAfter(end));

    final sales = _sales
        .where((s) => branchOk(s.branchId) && inRange(s.createdAt?.toDate()))
        .toList();
    final expenses = _expenses
        .where((e) => branchOk(e.branchId) && inRange(e.date?.toDate()))
        .toList();

    final employeeBranch = {for (final e in _employees) e.id: e.branchId};
    final salaries = _salaryPayments
        .where((p) =>
    branchOk(employeeBranch[p.employeeId] ?? '') &&
        inRange(p.createdAt?.toDate()))
        .toList();

    // ---- Assets ----
    double salesPaidBy(String method) => sales
        .where((s) => s.paymentMethod == method)
        .fold(0.0, (sum, s) => sum + s.paidAmount);
    double expensesPaidFrom(String account) => expenses
        .where((e) => e.cashBankAccount == account)
        .fold(0.0, (sum, e) => sum + e.amount);

    final cashSales = salesPaidBy('Cash');
    final cashExpenses = expensesPaidFrom('Cash in Hand');
    final bankSales = salesPaidBy('Bank Transfer');
    final bankExpenses = expensesPaidFrom('Bank Account');
    final onlineSales = salesPaidBy('Card');

    final receivableCustomers =
    _customers.where((c) => branchOk(c.branchId) && c.totalReceivable != 0).toList();
    final receivable =
    receivableCustomers.fold(0.0, (sum, c) => sum + c.totalReceivable);

    final productsInScope = _products.where((p) => branchOk(p.branchId));
    final productStock = productsInScope.fold(
        0.0, (sum, p) => sum + p.currentStock * p.purchasePrice);
    // Raw materials aren't assigned to a branch, so they only count in
    // the "All Branches" view.
    final rawStock = branchId == null
        ? _rawMaterials.fold(
        0.0, (sum, r) => sum + r.currentStock * r.costPerUnit)
        : 0.0;

    final assets = <SheetLine>[
      SheetLine('Accounts Receivable', receivable, details: [
        for (final c in receivableCustomers)
          SheetDetail(c.name, c.totalReceivable),
      ]),
      SheetLine('Bank Account', bankSales - bankExpenses, details: [
        SheetDetail('Sales received (bank transfer)', bankSales),
        SheetDetail('Expenses paid from bank', -bankExpenses),
      ]),
      SheetLine('Cash in Hand', cashSales - cashExpenses, details: [
        SheetDetail('Sales received (cash)', cashSales),
        SheetDetail('Expenses paid in cash', -cashExpenses),
      ]),
      const SheetLine('Furniture & Machinery', 0),
      SheetLine('Online Payment', onlineSales, details: [
        SheetDetail('Sales received (card)', onlineSales),
      ]),
      SheetLine('Stock/Inventory', productStock + rawStock, details: [
        SheetDetail('Products (at purchase cost)', productStock),
        if (branchId == null) SheetDetail('Raw materials', rawStock),
      ]),
    ];

    // ---- Liabilities & Equity ----
    final payableSuppliers =
    _suppliers.where((s) => branchOk(s.branchId) && s.totalPayable != 0).toList();
    final payable =
    payableSuppliers.fold(0.0, (sum, s) => sum + s.totalPayable);

    // Cost of goods sold = what the items we sold originally cost us.
    final costById = {for (final p in _products) p.id: p.purchasePrice};
    final cogs = sales.fold(
        0.0,
            (sum, s) =>
        sum +
            s.items.fold(0.0,
                    (t, i) => t + i.quantity * (costById[i.productId] ?? 0)));

    final grossSales = sales.fold(0.0, (sum, s) => sum + s.totalAmount);
    final discounts = sales.fold(0.0, (sum, s) => sum + s.discount);
    final revenue = grossSales - discounts;

    final headIds = _heads.map((h) => h.id).toSet();
    final expenseLines = <SheetLine>[
      for (final head in _heads)
            () {
          final items =
          expenses.where((e) => e.expenseHeadId == head.id).toList();
          return SheetLine(
            head.name,
            items.fold(0.0, (sum, e) => sum + e.amount),
            details: [
              for (final e in items)
                SheetDetail(
                  '${e.date != null ? _fmtDate(e.date!.toDate()) : '-'}'
                      '${e.description.isEmpty ? '' : ' · ${e.description}'}',
                  e.amount,
                ),
            ],
          );
        }(),
    ];
    final orphanExpenses =
    expenses.where((e) => !headIds.contains(e.expenseHeadId)).toList();
    if (orphanExpenses.isNotEmpty) {
      expenseLines.add(SheetLine(
        'Other Expenses',
        orphanExpenses.fold(0.0, (sum, e) => sum + e.amount),
        details: [
          for (final e in orphanExpenses)
            SheetDetail(
                e.description.isEmpty ? e.expenseHeadName : e.description,
                e.amount),
        ],
      ));
    }

    final salaryTotal = salaries.fold(0.0, (sum, p) => sum + p.amount);

    final liabilities = <SheetLine>[
      SheetLine('Accounts Payable', payable, details: [
        for (final s in payableSuppliers) SheetDetail(s.name, s.totalPayable),
      ]),
      SheetLine('COGS', cogs, details: [
        SheetDetail('Purchase cost of items sold', cogs),
      ]),
      ...expenseLines,
      SheetLine('STAFF SALARIES', salaryTotal, details: [
        for (final p in salaries)
          SheetDetail('${p.employeeName} · ${p.month}', p.amount),
      ]),
      const SheetLine('Capital/Owner Equity', 0),
      SheetLine('Sales Revenue', revenue, details: [
        SheetDetail('Gross sales', grossSales),
        SheetDetail('Discounts', -discounts),
      ]),
    ];

    return (assets: assets, liabilities: liabilities);
  }

  double _sum(List<SheetLine> lines) =>
      lines.fold(0.0, (sum, l) => sum + l.amount);

  Future<void> _printPdf(List<SheetLine> assets, List<SheetLine> liabilities) async {
    try {
      await printBalanceSheet(
        branchLabel: selectedBranchName.value ?? 'All Branches',
        from: _from,
        to: _to,
        assets: assets,
        liabilities: liabilities,
        totalAssets: _sum(assets),
        totalLiabilities: _sum(liabilities),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create PDF: $e')),
        );
      }
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, _, __) {
        final data = _compute();
        final totalAssets = _sum(data.assets);
        final totalLiabilities = _sum(data.liabilities);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterBar(data.assets, data.liabilities),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 800;
                final assetsPanel = _buildPanel(
                  title: 'ASSETS',
                  keyPrefix: 'a',
                  lines: data.assets,
                  totalLabel: 'TOTAL ASSETS',
                  total: totalAssets,
                );
                final liabilitiesPanel = _buildPanel(
                  title: 'LIABILITIES & EQUITY',
                  keyPrefix: 'l',
                  lines: data.liabilities,
                  totalLabel: 'TOTAL LIAB + EQUITY',
                  total: totalLiabilities,
                );

                if (stacked) {
                  return Column(
                    children: [
                      assetsPanel,
                      const SizedBox(height: 16),
                      liabilitiesPanel,
                    ],
                  );
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: assetsPanel),
                      Container(width: 2, color: _Palette.blue),
                      Expanded(child: liabilitiesPanel),
                    ],
                  ),
                );
              },
            ),
            if (selectedBranchId.value != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Raw materials are not assigned to a branch, so they are '
                    'counted only in the All Branches view. Stock, '
                    'receivable and payable are as of today; sales, '
                    'expenses and salaries follow the date range above.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(List<SheetLine> assets, List<SheetLine> liabilities) {
    Widget dateField(DateTime value, bool isFrom) {
      return InkWell(
        onTap: () => _pickDate(isFrom: isFrom),
        child: Container(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(child: Text(_fmtDate(value))),
              const Icon(Icons.calendar_today_outlined, size: 16),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Palette.filterBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('From:', style: TextStyle(fontSize: 16)),
          dateField(_pendingFrom, true),
          const Text('To:', style: TextStyle(fontSize: 16)),
          dateField(_pendingTo, false),
          ElevatedButton(
            onPressed: () => setState(() {
              _from = _pendingFrom;
              _to = _pendingTo;
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: _Palette.blue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Apply Filter'),
          ),
          ElevatedButton(
            onPressed: () => _printPdf(assets, liabilities),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF212529),
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Print PDF'),
          ),
          ValueListenableBuilder<String?>(
            valueListenable: selectedBranchName,
            builder: (context, name, _) => Text(
              name ?? 'All Branches',
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    required String keyPrefix,
    required List<SheetLine> lines,
    required String totalLabel,
    required double total,
  }) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: _Palette.blue,
            padding: const EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ...lines.asMap().entries.map((entry) {
            final key = '$keyPrefix${entry.key}';
            return _buildLine(key, entry.value);
          }),
          Container(
            color: _Palette.dark,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(totalLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                Text(_fmtAmount(total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLine(String key, SheetLine line) {
    final isOpen = _expanded.contains(key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (isOpen) {
              _expanded.remove(key);
            } else {
              _expanded.add(key);
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FA),
              border: Border(bottom: BorderSide(color: _Palette.line)),
            ),
            child: Row(
              children: [
                Text(isOpen ? '−  ' : '+  ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(line.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Text(_fmtAmount(line.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ),
        if (isOpen)
          Container(
            padding: const EdgeInsets.fromLTRB(46, 10, 24, 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _Palette.line)),
            ),
            child: line.details.isEmpty
                ? const Text('No transactions in this period.',
                style: TextStyle(color: Colors.grey, fontSize: 13))
                : Column(
              children: line.details
                  .map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(d.label,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 13)),
                    ),
                    Text(_fmtAmount(d.amount),
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13)),
                  ],
                ),
              ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}