import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/employee.dart';
import '../../models/expense.dart';
import '../../models/payments.dart';
import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../models/salary_payment.dart';
import '../../models/sales.dart';
import '../../models/supplier.dart';
import '../../services/customer_service.dart';
import '../../services/employee_service.dart';
import '../../services/expense_service.dart';
import '../../services/payment_service.dart';
import '../../services/product_service.dart';
import '../../services/purchase_service.dart';
import '../../services/sale_service.dart';
import '../../services/salary_service.dart';
import '../../services/supplier_service.dart';
import '../../utils/branch_filter.dart';

const Color _kBlue = Color(0xFF3159C9);
const Color _kGreen = Color(0xFF16A673);
const Color _kRed = Color(0xFFD9362F);

const List<String> _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// One line in "Recent Activity".
class _Activity {
  final DateTime time;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final double amount;
  final bool incoming; // true = money in (green), false = money out (red)

  const _Activity(this.time, this.icon, this.color, this.title, this.subtitle,
      this.amount, this.incoming);
}

/// Everything on the Dashboard page. All numbers, the chart and the recent
/// activity list follow the branch chosen in the top bar.
class DashboardHome extends StatefulWidget {
  final VoidCallback onAddProduct;
  final VoidCallback onNewPurchase;
  final VoidCallback onAddCustomer;

  const DashboardHome({
    super.key,
    required this.onAddProduct,
    required this.onNewPurchase,
    required this.onAddCustomer,
  });

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  List<Product> _products = [];
  List<Sale> _sales = [];
  List<Purchase> _purchases = [];
  List<Customer> _customers = [];
  List<Supplier> _suppliers = [];
  List<Employee> _employees = [];
  List<Expense> _expenses = [];
  List<Payment> _payments = [];
  List<SalaryPayment> _salaries = [];
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();

    void listen<T>(Stream<T> stream, void Function(T) assign) {
      _subs.add(stream.listen((d) {
        if (!mounted) return;
        setState(() => assign(d));
      }, onError: (_) {}));
    }

    listen(ProductService().streamProducts(), (d) => _products = d);
    listen(SaleService().streamSales(), (d) => _sales = d);
    listen(PurchaseService().streamPurchases(), (d) => _purchases = d);
    listen(CustomerService().streamCustomers(), (d) => _customers = d);
    listen(SupplierService().streamSuppliers(), (d) => _suppliers = d);
    listen(EmployeeService().streamEmployees(), (d) => _employees = d);
    listen(ExpenseService().streamExpenses(), (d) => _expenses = d);
    listen(PaymentService().streamPayments(), (d) => _payments = d);
    listen(SalaryService().streamSalaryPayments(), (d) => _salaries = d);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  // ================= HELPERS =================

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

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.round().toString();
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays == 1) return 'Yesterday';
    return '${t.day} ${_monthShort[t.month - 1]} ${t.year}';
  }

  // ================= RECENT ACTIVITY =================

  List<_Activity> _activities(String? branchId) {
    bool ok(String id) => branchId == null || id == branchId;
    final out = <_Activity>[];

    for (final s in _sales) {
      if (!ok(s.branchId)) continue;
      out.add(_Activity(
        s.createdAt?.toDate() ?? DateTime.now(),
        Icons.point_of_sale_outlined,
        _kBlue,
        'Sale · Invoice #${s.invoiceNumber}',
        '${s.customerName} · ${s.paymentMethod}',
        s.netAmount,
        true,
      ));
    }

    for (final p in _purchases) {
      if (!ok(p.branchId)) continue;
      out.add(_Activity(
        p.createdAt?.toDate() ?? DateTime.now(),
        Icons.shopping_bag_outlined,
        _kGreen,
        'Purchase from ${p.supplierName}',
        'Paid ${_n(p.paidAmount)} · Due ${_n(p.dueAmount)}',
        p.totalAmount,
        false,
      ));
    }

    for (final e in _expenses) {
      if (!ok(e.branchId)) continue;
      final head = e.expenseHeadName.isEmpty ? 'General' : e.expenseHeadName;
      out.add(_Activity(
        e.date?.toDate() ?? e.createdAt?.toDate() ?? DateTime.now(),
        Icons.receipt_long_outlined,
        const Color(0xFFE8A900),
        'Expense · $head',
        e.description.isEmpty ? e.expenseAccountName : e.description,
        e.amount,
        false,
      ));
    }

    final empBranch = {for (final e in _employees) e.id: e.branchId};
    for (final p in _salaries) {
      if (!ok(empBranch[p.employeeId] ?? '')) continue;
      out.add(_Activity(
        p.createdAt?.toDate() ?? DateTime.now(),
        Icons.badge_outlined,
        const Color(0xFF299FB0),
        'Salary · ${p.employeeName}',
        p.month,
        p.amount,
        false,
      ));
    }

    final custBranch = {for (final c in _customers) c.id: c.branchId};
    final suppBranch = {for (final s in _suppliers) s.id: s.branchId};
    for (final p in _payments) {
      final isSupplier = p.partyType == 'supplier';
      final b =
          (isSupplier ? suppBranch[p.partyId] : custBranch[p.partyId]) ?? '';
      if (!ok(b)) continue;
      out.add(_Activity(
        p.createdAt?.toDate() ?? DateTime.now(),
        isSupplier ? Icons.north_east : Icons.south_west,
        isSupplier ? _kRed : _kGreen,
        isSupplier ? 'Paid to ${p.partyName}' : 'Received from ${p.partyName}',
        isSupplier ? 'Supplier payment' : 'Customer payment',
        p.amount,
        !isSupplier,
      ));
    }

    out.sort((a, b) => b.time.compareTo(a.time));
    return out.take(10).toList();
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever the branch picked in the top bar changes.
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchId, _) {
        bool ok(String id) => branchId == null || id == branchId;

        final products = _products.where((p) => ok(p.branchId)).toList();
        final sales = _sales.where((s) => ok(s.branchId)).toList();
        final purchases = _purchases.where((p) => ok(p.branchId)).toList();
        final customers = _customers.where((c) => ok(c.branchId)).toList();
        final suppliers = _suppliers.where((s) => ok(s.branchId)).toList();
        final employees = _employees.where((e) => ok(e.branchId)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<String?>(
              valueListenable: selectedBranchName,
              builder: (context, branchName, _) {
                return Text(
                  branchName == null
                      ? 'Welcome back, Admin 👋'
                      : 'Welcome back, Admin — $branchName 👋',
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                );
              },
            ),
            const SizedBox(height: 6),
            const Text('Here is your business overview.',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 25),
            GridView(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 230,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                childAspectRatio: 1.7,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _statCard('Stock', _n(products.fold(0.0, (s, p) => s + p.currentStock)),
                    Icons.inventory_2_outlined, const Color(0xFF299FB0)),
                _statCard('Sales', _n(sales.fold(0.0, (s, x) => s + x.totalAmount)),
                    Icons.point_of_sale_outlined, _kBlue),
                _statCard('Purchase',
                    _n(purchases.fold(0.0, (s, p) => s + p.totalAmount)),
                    Icons.shopping_bag_outlined, _kGreen),
                _statCard('Receivable',
                    _n(customers.fold(0.0, (s, c) => s + c.totalReceivable)),
                    Icons.person_add_alt_1_outlined, const Color(0xFFE8A900)),
                _statCard('Payable',
                    _n(suppliers.fold(0.0, (s, x) => s + x.totalPayable)),
                    Icons.person_remove_outlined, _kRed),
                _statCard('Customers', '${customers.length}',
                    Icons.people_outline, const Color(0xFFE8A900)),
                _statCard('Suppliers', '${suppliers.length}',
                    Icons.local_shipping_outlined, const Color(0xFF7B61C9)),
                _statCard('Employees', '${employees.length}',
                    Icons.badge_outlined, const Color(0xFF299FB0)),
              ],
            ),
            const SizedBox(height: 25),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 700) {
                  return Column(
                    children: [
                      _salesOverview(sales),
                      const SizedBox(height: 20),
                      _quickActions(),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _salesOverview(sales)),
                    const SizedBox(width: 20),
                    Expanded(child: _quickActions()),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            _recentActivity(_activities(branchId)),
          ],
        );
      },
    );
  }

  // ---------- stat card ----------

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                const SizedBox(height: 5),
                // Shrinks long numbers instead of cutting them with "...".
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      maxLines: 1,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10)],
  );

  // ---------- Sales Overview (last 6 months) ----------

  Widget _salesOverview(List<Sale> sales) {
    final now = DateTime.now();
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i, 1),
    ];
    final totals = List<double>.filled(6, 0);
    for (final s in sales) {
      final d = s.createdAt?.toDate();
      if (d == null) continue;
      for (var i = 0; i < 6; i++) {
        if (d.year == months[i].year && d.month == months[i].month) {
          totals[i] += s.totalAmount;
        }
      }
    }
    final maxV = totals.fold<double>(0, (m, v) => v > m ? v : m);
    final sum = totals.fold<double>(0, (s, v) => s + v);

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Sales Overview',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Text(_n(sum),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: _kBlue)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Monthly sales — last 6 months',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          Expanded(
            child: maxV <= 0
                ? const Center(
              child: Text('No sales in the last 6 months.',
                  style: TextStyle(color: Colors.grey)),
            )
                : LayoutBuilder(builder: (context, c) {
              // Room kept for the value label above (~14), gaps (4 + 6) and
              // the month name below (~14), plus a safety margin so text
              // scaling can never overflow the column.
              final barArea = (c.maxHeight - 58).clamp(20.0, 400.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 6; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(_compact(totals[i]),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 22,
                            height: totals[i] <= 0
                                ? 3
                                : (totals[i] / maxV * barArea)
                                .clamp(3.0, barArea),
                            decoration: BoxDecoration(
                              color: i == 5
                                  ? _kBlue
                                  : _kBlue.withOpacity(0.35),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_monthShort[months[i].month - 1],
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ---------- Quick Actions ----------

  Widget _quickActions() {
    Widget action(String title, IconData icon, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          width: double.infinity,
          height: 43,
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 19),
            label: Text(title),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          action('Add Product', Icons.add_box_outlined, widget.onAddProduct),
          action('New Purchase', Icons.shopping_cart_outlined,
              widget.onNewPurchase),
          action('Add Customer', Icons.person_add_outlined,
              widget.onAddCustomer),
        ],
      ),
    );
  }

  // ---------- Recent Activity ----------

  Widget _recentActivity(List<_Activity> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(25),
                child: Text('No recent activity',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFEEF0F3)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: items[i].color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(items[i].icon, color: items[i].color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        if (items[i].subtitle.isNotEmpty)
                          Text(items[i].subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${items[i].incoming ? '+' : '-'}${_n(items[i].amount)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: items[i].incoming ? _kGreen : _kRed),
                      ),
                      Text(_ago(items[i].time),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}