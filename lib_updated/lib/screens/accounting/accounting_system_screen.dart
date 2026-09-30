import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/employee.dart';
import '../../models/expense.dart';
import '../../models/expense_account.dart';
import '../../models/expense_head.dart';
import '../../models/payments.dart';
import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../models/salary_payment.dart';
import '../../models/sales.dart';
import '../../models/supplier.dart';
import '../../services/customer_service.dart';
import '../../services/employee_service.dart';
import '../../services/expense_account_service.dart';
import '../../services/expense_head_service.dart';
import '../../services/expense_service.dart';
import '../../services/payment_service.dart';
import '../../services/product_service.dart';
import '../../services/purchase_service.dart';
import '../../services/sale_service.dart';
import '../../services/salary_service.dart';
import '../../services/supplier_service.dart';
import '../../utils/branch_filter.dart';

// Same look as the "Accounting Master" reference: navy + Bootstrap blue,
// white cards, light-blue account tiles.
class _P {
  static const navy = Color(0xFF03213D);
  static const blue = Color(0xFF0D6EFD);
  static const green = Color(0xFF198754);
  static const red = Color(0xFFDC3545);
  static const cyan = Color(0xFF0DCAF0);
  static const tint = Color(0xFFEAF1FB);
  static const line = Color(0xFFDEE2E6);
  static const headBg = Color(0xFFF8F9FA);
  static const grey = Color(0xFF6C757D);
}

// Fixed (system) accounts that always exist.
class _Sys {
  final String name;
  final String kind;
  final bool protected; // red shield instead of grey lock
  const _Sys(this.name, this.kind, {this.protected = false});
}

const List<_Sys> _systemAccounts = [
  _Sys('Cash in Hand', 'Assets'),
  _Sys('Bank Account', 'Assets'),
  _Sys('Online Payment', 'Assets'),
  _Sys('Accounts Receivable', 'Assets'),
  _Sys('Stock/Inventory', 'Assets'),
  _Sys('Furniture & Machinery', 'Assets'),
  _Sys('Accounts Payable', 'Liabilities'),
  _Sys('Capital/Owner Equity', 'Owner Equity', protected: true),
  _Sys('Sales Revenue', 'Revenue', protected: true),
  _Sys('COGS', 'Expenses', protected: true),
  _Sys('STAFF SALARIES', 'Expenses'),
];

const List<String> _kindOrder = [
  'Assets',
  'Liabilities',
  'Owner Equity',
  'Revenue',
  'Expenses',
];

// One line of a voucher (double entry: every voucher has Dr = Cr).
class _Entry {
  final int seq;
  final DateTime date;
  final String voucher;
  final String type;
  final String account;
  final String head;
  final String kind;
  final String description;
  final double debit;
  final double credit;

  const _Entry(this.seq, this.date, this.voucher, this.type, this.account,
      this.head, this.kind, this.description, this.debit, this.credit);
}

class _TbRow {
  final String account;
  final String kind;
  double debit = 0;
  double credit = 0;
  _TbRow(this.account, this.kind);
  double get net => debit - credit;
}

class AccountingSystemScreen extends StatefulWidget {
  const AccountingSystemScreen({super.key});

  @override
  State<AccountingSystemScreen> createState() =>
      _AccountingSystemScreenState();
}

class _AccountingSystemScreenState extends State<AccountingSystemScreen> {
  List<Sale> _sales = [];
  List<Purchase> _purchases = [];
  List<Expense> _expenses = [];
  List<SalaryPayment> _salaries = [];
  List<Payment> _payments = [];
  List<Employee> _employees = [];
  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
  List<Product> _products = [];
  List<ExpenseHead> _heads = [];
  List<ExpenseAccount> _accounts = [];
  final List<StreamSubscription> _subs = [];

  int _tab = 0; // 0 Day Book, 1 Trial Balance, 2 Balance Sheet

  // Ledger is rebuilt only when data or the selected branch changes.
  List<_Entry>? _cache;
  String? _cacheBranch;

  @override
  void initState() {
    super.initState();

    void listen<T>(Stream<T> stream, void Function(T) assign) {
      _subs.add(stream.listen((data) {
        if (!mounted) return;
        setState(() {
          assign(data);
          _cache = null;
        });
      }, onError: (_) {}));
    }

    listen(SaleService().streamSales(), (d) => _sales = d);
    listen(PurchaseService().streamPurchases(), (d) => _purchases = d);
    listen(ExpenseService().streamExpenses(), (d) => _expenses = d);
    listen(SalaryService().streamSalaryPayments(), (d) => _salaries = d);
    listen(PaymentService().streamPayments(), (d) => _payments = d);
    listen(EmployeeService().streamEmployees(), (d) => _employees = d);
    listen(CustomerService().streamCustomers(), (d) => _customers = d);
    listen(SupplierService().streamSuppliers(), (d) => _suppliers = d);
    listen(ProductService().streamProducts(), (d) => _products = d);
    listen(ExpenseHeadService().streamExpenseHeads(), (d) => _heads = d);
    listen(ExpenseAccountService().streamExpenseAccounts(),
            (d) => _accounts = d);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // ================= LEDGER =================

  String _short(String id) =>
      (id.length > 5 ? id.substring(0, 5) : id).toUpperCase();

  String _accountForMethod(String method) {
    switch (method) {
      case 'Bank Transfer':
        return 'Bank Account';
      case 'Card':
        return 'Online Payment';
      default:
        return 'Cash in Hand';
    }
  }

  List<_Entry> _entries(String? branchId) {
    if (_cache != null && _cacheBranch == branchId) return _cache!;

    bool ok(String id) => branchId == null || id == branchId;
    final out = <_Entry>[];
    var seq = 0;

    void add(DateTime d, String voucher, String type, String account,
        String kind, String desc,
        {double dr = 0, double cr = 0, String? head}) {
      if (dr == 0 && cr == 0) return;
      out.add(_Entry(
          seq++, d, voucher, type, account, head ?? account, kind, desc, dr, cr));
    }

    // ---- Sales ----
    final cost = {for (final p in _products) p.id: p.purchasePrice};
    for (final s in _sales) {
      if (!ok(s.branchId)) continue;
      final d = s.createdAt?.toDate() ?? DateTime.now();
      final v = 'S-${s.invoiceNumber}';
      final inv = 'InvoiceNo: ${s.invoiceNumber}';

      add(d, v, 'Sale', _accountForMethod(s.paymentMethod), 'Assets',
          '${s.paymentMethod} on $inv',
          dr: s.paidAmount);
      final due = s.dueAmount;
      if (due > 0) {
        add(d, v, 'Sale', 'Accounts Receivable', 'Assets',
            'Credit sale on $inv · ${s.customerName}',
            dr: due);
      } else if (due < 0) {
        add(d, v, 'Sale', 'Accounts Receivable', 'Assets',
            'Overpaid on $inv · ${s.customerName}',
            cr: -due);
      }
      add(d, v, 'Sale', 'Sales Revenue', 'Revenue',
          'Sales Revenue for $inv',
          cr: s.netAmount);

      final cogs = s.items
          .fold<double>(0, (t, i) => t + i.quantity * (cost[i.productId] ?? 0));
      add(d, v, 'Sale', 'COGS', 'Expenses', 'COGS for $inv', dr: cogs);
      add(d, v, 'Sale', 'Stock/Inventory', 'Assets', 'Stock Out - $inv',
          cr: cogs);
    }

    // ---- Purchases ----
    for (final p in _purchases) {
      if (!ok(p.branchId)) continue;
      final d = p.createdAt?.toDate() ?? DateTime.now();
      final v = 'P-${_short(p.id)}';
      add(d, v, 'Purchase', 'Stock/Inventory', 'Assets',
          'Stock In - Purchase from ${p.supplierName}',
          dr: p.totalAmount);
      add(d, v, 'Purchase', 'Cash in Hand', 'Assets',
          'Paid to ${p.supplierName}',
          cr: p.paidAmount);
      final due = p.dueAmount;
      if (due > 0) {
        add(d, v, 'Purchase', 'Accounts Payable', 'Liabilities',
            'Payable to ${p.supplierName}',
            cr: due);
      } else if (due < 0) {
        add(d, v, 'Purchase', 'Accounts Payable', 'Liabilities',
            'Overpaid to ${p.supplierName}',
            dr: -due);
      }
    }

    // ---- Expenses ----
    for (final e in _expenses) {
      if (!ok(e.branchId)) continue;
      final d = e.date?.toDate() ?? e.createdAt?.toDate() ?? DateTime.now();
      final v = 'E-${_short(e.id)}';
      final head =
      e.expenseHeadName.isEmpty ? 'General Expenses' : e.expenseHeadName;
      final acct = e.expenseAccountName.isEmpty ? head : e.expenseAccountName;
      final cash =
      e.cashBankAccount == 'Bank Account' ? 'Bank Account' : 'Cash in Hand';
      add(d, v, 'Expense', acct, 'Expenses',
          e.description.isEmpty ? '$head expense' : e.description,
          dr: e.amount, head: head);
      add(d, v, 'Expense', cash, 'Assets', 'Paid for $head', cr: e.amount);
    }

    // ---- Salaries (branch comes from the employee) ----
    final empBranch = {for (final e in _employees) e.id: e.branchId};
    for (final p in _salaries) {
      if (!ok(empBranch[p.employeeId] ?? '')) continue;
      final d = p.createdAt?.toDate() ?? DateTime.now();
      final v = 'SAL-${_short(p.id)}';
      add(d, v, 'Salary', 'STAFF SALARIES', 'Expenses',
          'Salary · ${p.employeeName} · ${p.month}',
          dr: p.amount);
      add(d, v, 'Salary', 'Cash in Hand', 'Assets',
          'Salary paid to ${p.employeeName}',
          cr: p.amount);
    }

    // ---- Party payments (branch comes from the customer/supplier) ----
    final custBranch = {for (final c in _customers) c.id: c.branchId};
    final suppBranch = {for (final s in _suppliers) s.id: s.branchId};
    for (final p in _payments) {
      final isSupplier = p.partyType == 'supplier';
      final b = (isSupplier ? suppBranch[p.partyId] : custBranch[p.partyId]) ??
          '';
      if (!ok(b)) continue;
      final d = p.createdAt?.toDate() ?? DateTime.now();
      final v = 'PAY-${_short(p.id)}';
      if (isSupplier) {
        add(d, v, 'Payment', 'Accounts Payable', 'Liabilities',
            'Paid to ${p.partyName}',
            dr: p.amount);
        add(d, v, 'Payment', 'Cash in Hand', 'Assets',
            'Payment to ${p.partyName}',
            cr: p.amount);
      } else {
        add(d, v, 'Receipt', 'Cash in Hand', 'Assets',
            'Received from ${p.partyName}',
            dr: p.amount);
        add(d, v, 'Receipt', 'Accounts Receivable', 'Assets',
            'Payment received from ${p.partyName}',
            cr: p.amount);
      }
    }

    // Newest first; lines of one voucher stay together and in order.
    out.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : a.seq.compareTo(b.seq);
    });

    _cache = out;
    _cacheBranch = branchId;
    return out;
  }

  List<_TbRow> _trialBalance(List<_Entry> entries) {
    final map = <String, _TbRow>{};
    for (final e in entries) {
      final row = map.putIfAbsent('${e.kind}|${e.account}',
              () => _TbRow(e.account, e.kind));
      row.debit += e.debit;
      row.credit += e.credit;
    }
    final rows = map.values.toList();
    rows.sort((a, b) {
      final k = _kindOrder.indexOf(a.kind).compareTo(_kindOrder.indexOf(b.kind));
      return k != 0 ? k : a.account.compareTo(b.account);
    });
    return rows;
  }

  // ================= FORMATTING =================

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${_months[d.month - 1]}-${d.year}';

  String _money(double v) {
    final neg = v < -0.004;
    final parts = v.abs().toStringAsFixed(2).split('.');
    final digits = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${neg ? '-' : ''}$buf.${parts[1]}';
  }

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: color, content: Text(msg)),
    );
  }

  // ================= ACTIONS =================

  // Eye icon: opens every transaction of that head / account (for the
  // branch chosen in the top bar) with its totals.
  void _viewAccount(String kind, String name) {
    final rows = _entries(selectedBranchId.value)
        .where((e) => kind == 'head' ? e.head == name : e.account == name)
        .toList();
    final dr = rows.fold<double>(0, (s, e) => s + e.debit);
    final cr = rows.fold<double>(0, (s, e) => s + e.credit);
    final net = dr - cr;

    Widget stat(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: _P.tint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(color: _P.grey, fontSize: 12)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ),
            ],
          ),
        ),
      );
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(selectedBranchName.value ?? 'All Branches',
                    style: const TextStyle(color: _P.grey, fontSize: 13)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    stat('Total Debit', _money(dr), _P.green),
                    const SizedBox(width: 10),
                    stat('Total Credit', _money(cr), _P.red),
                    const SizedBox(width: 10),
                    stat('Balance', '${_money(net.abs())} ${net >= 0 ? 'Dr' : 'Cr'}',
                        _P.blue),
                  ],
                ),
                const SizedBox(height: 14),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text('No transactions found for this account.',
                          style: TextStyle(color: _P.grey)),
                    ),
                  )
                else
                  Flexible(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth < 680 ? 680.0 : c.maxWidth;
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: w,
                            child: Column(
                              children: [
                                Container(
                                  color: _P.headBg,
                                  child: Row(
                                    children: [
                                      _cell('Date', flex: 18, header: true),
                                      _cell('Voucher', flex: 14, header: true),
                                      _cell('Type', flex: 12, header: true),
                                      _cell('Description',
                                          flex: 32, header: true),
                                      _cell('Debit',
                                          flex: 12, header: true, right: true),
                                      _cell('Credit',
                                          flex: 12, header: true, right: true),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: rows.length,
                                    itemBuilder: (context, i) {
                                      final e = rows[i];
                                      return Row(
                                        children: [
                                          _cell(_fmtDate(e.date), flex: 18),
                                          _cell(e.voucher, flex: 14),
                                          _cell(e.type, flex: 12),
                                          _cell(e.description, flex: 32),
                                          _cell(_money(e.debit),
                                              flex: 12, right: true),
                                          _cell(_money(e.credit),
                                              flex: 12, right: true),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addNameDialog(
      {required String title, required Future<void> Function(String) onSave}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await onSave(name);
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  // "New Transaction" = a new expense voucher (Dr expense, Cr cash/bank).
  // The dialog only collects values; saving happens after it has closed.
  Future<void> _newTransaction() async {
    final branchId = selectedBranchId.value;
    if (branchId == null) {
      _snack('Select a branch from the top bar before adding a transaction.');
      return;
    }
    final branchName = selectedBranchName.value ?? '';

    final res = await showDialog<_TxResult>(
      context: context,
      builder: (_) => _NewTransactionDialog(
        branchName: branchName,
        heads: List.of(_heads),
        accounts: List.of(_accounts),
      ),
    );
    if (res == null || !mounted) return;

    try {
      await ExpenseService().addExpense(Expense(
        id: '',
        branchId: branchId,
        branchName: branchName,
        expenseHeadId: res.head.id,
        expenseHeadName: res.head.name,
        expenseAccountId: res.account?.id ?? '',
        expenseAccountName: res.account?.name ?? '',
        cashBankAccount: res.paidFrom,
        amount: res.amount,
        description: res.description,
        date: Timestamp.now(),
      ));
      if (mounted) _snack('Transaction saved.', color: _P.green);
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
        final all = _entries(branchId);

        double revenue = 0, expenses = 0;
        for (final e in all) {
          if (e.kind == 'Revenue') revenue += e.credit - e.debit;
          if (e.kind == 'Expenses') expenses += e.debit - e.credit;
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1150;

            final center = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const SizedBox(height: 16),
                _summaryCard(revenue, expenses, revenue - expenses),
                const SizedBox(height: 18),
                _tabBar(),
                const SizedBox(height: 12),
                Container(
                  height: 540,
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: _cardDecoration(),
                  child: _tabBody(all),
                ),
              ],
            );

            final heads = _headsPanel();
            final chart = _chartPanel();

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 290, height: 800, child: heads),
                  const SizedBox(width: 18),
                  Expanded(child: center),
                  const SizedBox(width: 18),
                  SizedBox(width: 290, height: 800, child: chart),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                center,
                const SizedBox(height: 18),
                SizedBox(height: 420, child: heads),
                const SizedBox(height: 18),
                SizedBox(height: 420, child: chart),
              ],
            );
          },
        );
      },
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8)],
  );

  // ---------- header ----------

  Widget _header() {
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchName,
      builder: (context, branchName, _) {
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Accounting Master',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_tree_outlined,
                        size: 15, color: _P.grey),
                    const SizedBox(width: 6),
                    Text(
                      branchName ?? 'All Branches',
                      style: const TextStyle(
                          color: _P.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _newTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.blue,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              ),
              child: const Text('New Transaction',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  // ---------- Revenue / Expenses / Net Profit ----------

  Widget _summaryCard(double revenue, double expenses, double profit) {
    Widget stat(String label, double value, Color color) {
      return Expanded(
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(color: _P.grey, fontSize: 14)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _money(value),
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(height: 4, color: _P.blue),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
              child: Row(
                children: [
                  stat('Revenue', revenue, _P.green),
                  stat('Expenses', expenses, _P.red),
                  stat('Net Profit', profit, _P.blue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- tabs ----------

  Widget _tabBar() {
    const labels = ['Day Book', 'Trial Balance', 'Balance Sheet'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _tab == i ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _tab == i ? _P.line : Colors.transparent),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _tab == i ? Colors.black87 : _P.blue,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabBody(List<_Entry> all) {
    switch (_tab) {
      case 1:
        return _trialBalanceView(all);
      case 2:
        return _balanceSheetView(all);
      default:
        return _dayBookView(all);
    }
  }

  // ---------- table cell helper ----------

  Widget _cell(String text,
      {required int flex,
        bool right = false,
        bool header = false,
        Color? color,
        bool bold = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        alignment: right ? Alignment.centerRight : Alignment.centerLeft,
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: _P.line),
            bottom: BorderSide(color: _P.line),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: (header || bold) ? FontWeight.w700 : FontWeight.w400,
            color: color ?? Colors.black87,
          ),
        ),
      ),
    );
  }

  // ---------- Day Book ----------

  Widget _dayBookView(List<_Entry> rows) {
    final totalDr = rows.fold<double>(0, (s, e) => s + e.debit);
    final totalCr = rows.fold<double>(0, (s, e) => s + e.credit);

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth < 820 ? 820.0 : c.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: w,
                  child: Column(
                    children: [
                      Container(
                        color: _P.headBg,
                        child: Row(
                          children: [
                            _cell('Date', flex: 18, header: true),
                            _cell('Voucher', flex: 13, header: true),
                            _cell('Type', flex: 12, header: true),
                            _cell('Account', flex: 20, header: true),
                            _cell('Description', flex: 32, header: true),
                            _cell('Debit', flex: 15, header: true, right: true),
                            _cell('Credit', flex: 15, header: true, right: true),
                          ],
                        ),
                      ),
                      Expanded(
                        child: rows.isEmpty
                            ? const Center(
                          child: Text('No transactions for this branch yet.',
                              style: TextStyle(color: _P.grey)),
                        )
                            : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final e = rows[i];
                            return Row(
                              children: [
                                _cell(_fmtDate(e.date), flex: 18),
                                _cell(e.voucher, flex: 13),
                                _cell(e.type, flex: 12),
                                _cell(e.account, flex: 20),
                                _cell(e.description, flex: 32),
                                _cell(_money(e.debit),
                                    flex: 15, right: true),
                                _cell(_money(e.credit),
                                    flex: 15, right: true),
                              ],
                            );
                          },
                        ),
                      ),
                      Container(
                        color: _P.headBg,
                        child: Row(
                          children: [
                            _cell('Total', flex: 95, header: true),
                            _cell(_money(totalDr),
                                flex: 15, header: true, right: true),
                            _cell(_money(totalCr),
                                flex: 15, header: true, right: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------- Trial Balance ----------

  Widget _trialBalanceView(List<_Entry> all) {
    final rows = _trialBalance(all);
    var totalDr = 0.0, totalCr = 0.0;
    for (final r in rows) {
      if (r.net >= 0) {
        totalDr += r.net;
      } else {
        totalCr += -r.net;
      }
    }
    final balanced = (totalDr - totalCr).abs() < 0.01;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth < 560 ? 560.0 : c.maxWidth;
        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: w,
              child: Column(
                children: [
                  Container(
                    color: _P.headBg,
                    child: Row(
                      children: [
                        _cell('Account', flex: 40, header: true),
                        _cell('Type', flex: 20, header: true),
                        _cell('Debit', flex: 20, header: true, right: true),
                        _cell('Credit', flex: 20, header: true, right: true),
                      ],
                    ),
                  ),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Text('No transactions for this branch yet.',
                          style: TextStyle(color: _P.grey)),
                    ),
                  for (final r in rows)
                    Row(
                      children: [
                        _cell(r.account, flex: 40),
                        _cell(r.kind, flex: 20),
                        _cell(r.net > 0 ? _money(r.net) : '0.00',
                            flex: 20, right: true),
                        _cell(r.net < 0 ? _money(-r.net) : '0.00',
                            flex: 20, right: true),
                      ],
                    ),
                  Container(
                    color: _P.headBg,
                    child: Row(
                      children: [
                        _cell('Total', flex: 60, header: true),
                        _cell(_money(totalDr),
                            flex: 20, header: true, right: true),
                        _cell(_money(totalCr),
                            flex: 20, header: true, right: true),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        balanced ? 'Trial balance is balanced' : 'Not balanced',
                        style: TextStyle(
                            color: balanced ? _P.green : _P.red,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
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

  // ---------- Balance Sheet (built from the same ledger) ----------

  Widget _balanceSheetView(List<_Entry> all) {
    final rows = _trialBalance(all);

    final assets = <MapEntry<String, double>>[];
    final liabilities = <MapEntry<String, double>>[];
    var profit = 0.0;
    for (final r in rows) {
      switch (r.kind) {
        case 'Assets':
          if (r.net.abs() > 0.004) assets.add(MapEntry(r.account, r.net));
          break;
        case 'Liabilities':
        case 'Owner Equity':
          if (r.net.abs() > 0.004) liabilities.add(MapEntry(r.account, -r.net));
          break;
        case 'Revenue':
          profit += -r.net;
          break;
        case 'Expenses':
          profit -= r.net;
          break;
      }
    }
    liabilities.add(MapEntry('Net Profit (current)', profit));

    final totalA = assets.fold<double>(0, (s, e) => s + e.value);
    final totalL = liabilities.fold<double>(0, (s, e) => s + e.value);

    Widget panel(String title, List<MapEntry<String, double>> lines,
        String totalLabel, double total) {
      return Expanded(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _P.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: _P.navy,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                ),
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final l in lines)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: const BoxDecoration(
                          border:
                          Border(bottom: BorderSide(color: _P.line)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(l.key,
                                    style: const TextStyle(fontSize: 13))),
                            Text(_money(l.value),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                color: _P.headBg,
                child: Row(
                  children: [
                    Expanded(
                        child: Text(totalLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13))),
                    Text(_money(total),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final a = panel('ASSETS', assets, 'TOTAL ASSETS', totalA);
      final l = panel(
          'LIABILITIES & EQUITY', liabilities, 'TOTAL LIAB + EQUITY', totalL);
      if (c.maxWidth < 560) {
        return Column(children: [a, const SizedBox(height: 12), l]);
      }
      return Row(children: [a, const SizedBox(width: 12), l]);
    });
  }

  // ================= SIDE PANELS =================

  Widget _panel({
    required String title,
    required VoidCallback onAdd,
    required List<Widget> children,
  }) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3)),
                ),
                InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 34,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _P.blue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _P.line),
          Expanded(
            child: ListView(children: children),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required String name,
    required Widget subtitle,
    required bool protected,
    required VoidCallback onEye,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _P.tint,
        border: const Border(bottom: BorderSide(color: Colors.white, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                subtitle,
              ],
            ),
          ),
          Icon(protected ? Icons.shield : Icons.lock,
              size: 16, color: protected ? _P.red : Colors.black54),
          const SizedBox(width: 10),
          InkWell(
            onTap: onEye,
            child: const Icon(Icons.remove_red_eye, size: 20, color: _P.cyan),
          ),
        ],
      ),
    );
  }

  Widget _headsPanel() {
    return _panel(
      title: 'ACCOUNTS HEADS',
      onAdd: () => _addNameDialog(
        title: 'New Account Head',
        onSave: (n) => ExpenseHeadService().addExpenseHead(n),
      ),
      children: [
        for (final s in _systemAccounts)
          _tile(
            name: s.name,
            protected: s.protected,
            onEye: () => _viewAccount('head', s.name),
            subtitle: Row(children: [
              const Icon(Icons.sell, size: 12, color: _P.grey),
              const SizedBox(width: 4),
              Text(s.kind,
                  style: const TextStyle(fontSize: 12, color: _P.grey)),
            ]),
          ),
        for (final h in _heads)
          _tile(
            name: h.name,
            protected: false,
            onEye: () => _viewAccount('head', h.name),
            subtitle: const Row(children: [
              Icon(Icons.sell, size: 12, color: _P.grey),
              SizedBox(width: 4),
              Text('Expenses',
                  style: TextStyle(fontSize: 12, color: _P.grey)),
            ]),
          ),
      ],
    );
  }

  Widget _chartPanel() {
    // Parent head of each expense account, taken from its latest expense.
    final parent = <String, String>{};
    for (final e in _expenses) {
      if (e.expenseAccountName.isNotEmpty && e.expenseHeadName.isNotEmpty) {
        parent.putIfAbsent(e.expenseAccountName, () => e.expenseHeadName);
      }
    }

    return _panel(
      title: 'CHART OF ACCOUNTS',
      onAdd: () => _addNameDialog(
        title: 'New Account',
        onSave: (n) => ExpenseAccountService().addExpenseAccount(n),
      ),
      children: [
        if (_accounts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No accounts yet. Tap + to add one.',
                style: TextStyle(color: _P.grey)),
          ),
        for (final a in _accounts)
          _tile(
            name: a.name,
            protected: false,
            onEye: () => _viewAccount('account', a.name),
            subtitle: Row(children: [
              const Icon(Icons.folder_open, size: 13, color: _P.blue),
              const SizedBox(width: 4),
              Flexible(
                child: Text(parent[a.name] ?? 'Expense Account',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _P.blue)),
              ),
            ]),
          ),
      ],
    );
  }
}


class _NameDialog extends StatefulWidget {
  final String title;
  const _NameDialog({required this.title});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => Navigator.of(context).pop(_c.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_c.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _TxResult {
  final ExpenseHead head;
  final ExpenseAccount? account;
  final String paidFrom;
  final double amount;
  final String description;
  const _TxResult(
      this.head, this.account, this.paidFrom, this.amount, this.description);
}

class _NewTransactionDialog extends StatefulWidget {
  final String branchName;
  final List<ExpenseHead> heads;
  final List<ExpenseAccount> accounts;
  const _NewTransactionDialog({
    required this.branchName,
    required this.heads,
    required this.accounts,
  });

  @override
  State<_NewTransactionDialog> createState() => _NewTransactionDialogState();
}

class _NewTransactionDialogState extends State<_NewTransactionDialog> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  ExpenseHead? _head;
  ExpenseAccount? _account;
  String _paidFrom = 'Cash in Hand';
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (_head == null || amount <= 0) {
      setState(() => _error = 'Select an Expense Head and enter an amount.');
      return;
    }
    Navigator.of(context).pop(
        _TxResult(_head!, _account, _paidFrom, amount, _desc.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New Transaction — ${widget.branchName}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ExpenseHead>(
                value: _head,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Expense Head'),
                items: [
                  for (final h in widget.heads)
                    DropdownMenuItem(value: h, child: Text(h.name)),
                ],
                onChanged: (v) => setState(() {
                  _head = v;
                  _error = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ExpenseAccount>(
                value: _account,
                isExpanded: true,
                decoration:
                const InputDecoration(labelText: 'Expense Account (Dr)'),
                items: [
                  for (final a in widget.accounts)
                    DropdownMenuItem(value: a, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _account = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _paidFrom,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Paid From (Cr)'),
                items: const [
                  DropdownMenuItem(
                      value: 'Cash in Hand', child: Text('Cash in Hand')),
                  DropdownMenuItem(
                      value: 'Bank Account', child: Text('Bank Account')),
                ],
                onChanged: (v) =>
                    setState(() => _paidFrom = v ?? 'Cash in Hand'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() => _error = null),
                decoration:
                InputDecoration(labelText: 'Amount', errorText: _error),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
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