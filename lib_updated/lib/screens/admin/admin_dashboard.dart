import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/branch.dart';
import '../../services/auth_service.dart';
import '../../services/branch_service.dart';
import '../../services/customer_service.dart';
import '../../services/employee_service.dart';
import '../../services/product_service.dart';
import '../../services/purchase_service.dart';
import '../../services/sale_service.dart';
import '../../services/supplier_service.dart';
import '../../services/user_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/profile_avatar.dart';
import '../accounting/accounting_system_screen.dart';
import '../accounting/balance_sheet_screen.dart';
import '../accounting/generate_salary_screen.dart';
import '../accounting/salary_sheet_screen.dart';
import '../areas/areas_screen.dart';
import '../attendance/attendance_screen.dart';
import '../branches/branches_screen.dart';
import '../brands/brands_screen.dart';
import '../categories/categories_screen.dart';
import '../delete_invoice/delete_invoice_screen.dart';
import '../employees/employees_admin_screen.dart';
import '../expenses/expenses_screen.dart';
import '../inventory/inventory_screen.dart';
import '../parties/parties_screen.dart';
import '../payments/payments_screen.dart';
import '../products/products_screen.dart';
import '../purchases/purchases_screen.dart';
import '../raw_materials/raw_materials_screen.dart';
import '../reports/invoices_report_screen.dart';
import '../reports/parties_report_screen.dart';
import '../reports/reports_screen.dart';
import '../reports/stock_audit_screen.dart';
import '../reports/stock_report_screen.dart';
import '../settings/settings_screen.dart';

// Change this to your company's name - shown in the sidebar.
const String kCompanyName = 'MARKETING BOOSTER';
const String kAppTagline = 'MANAGEMENT SYSTEM';

class MenuEntry {
  final String key;
  final String title;
  final IconData icon;
  final List<MenuEntry>? children;

  const MenuEntry(this.key, this.title, this.icon, {this.children});
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final ProductService _productService = ProductService();
  final SaleService _saleService = SaleService();
  final PurchaseService _purchaseService = PurchaseService();
  final CustomerService _customerService = CustomerService();
  final SupplierService _supplierService = SupplierService();
  final EmployeeService _employeeService = EmployeeService();
  final BranchService _branchService = BranchService();

  String selectedKey = 'dashboard';
  bool sidebarCollapsed = false;
  final Set<String> _expandedGroups = {};

  final Color navy = const Color(0xFF03213D);
  final Color blue = const Color(0xFF3159C9);
  final Color background = const Color(0xFFF5F7FA);

  late final List<MenuEntry> _menu = [
    const MenuEntry('dashboard', 'Dashboard', Icons.dashboard_outlined),
    const MenuEntry(
      'administration',
      'Administration',
      Icons.admin_panel_settings_outlined,
      children: [
        MenuEntry('employees', 'Employees', Icons.badge_outlined),
        MenuEntry('parties', 'Parties', Icons.groups_outlined),
        MenuEntry('areas', 'Areas', Icons.map_outlined),
      ],
    ),
    const MenuEntry(
      'reports',
      'Reports',
      Icons.bar_chart_outlined,
      children: [
        MenuEntry('invoices_report', 'Invoices Report',
            Icons.receipt_long_outlined),
        MenuEntry('stock_audit', 'Stock Audit', Icons.fact_check_outlined),
        MenuEntry('stock_report', 'Stock Report', Icons.inventory_outlined),
        MenuEntry(
            'parties_report', 'Parties Report', Icons.groups_outlined),
      ],
    ),
    const MenuEntry(
      'inventory_group',
      'Inventory',
      Icons.warehouse_outlined,
      children: [
        MenuEntry('items', 'Items', Icons.inventory_2_outlined),
        MenuEntry('categories', 'Categories', Icons.category_outlined),
        MenuEntry('brands', 'Brands', Icons.branding_watermark_outlined),
        MenuEntry('raw_materials', 'Raw Materials', Icons.grain_outlined),
        MenuEntry(
            'stock_adjustment', 'Stock Adjustment', Icons.tune_outlined),
      ],
    ),
    const MenuEntry('branches', 'Branches', Icons.account_tree_outlined),
    const MenuEntry(
        'purchases', 'Purchases', Icons.shopping_bag_outlined),
    const MenuEntry(
        'delete_invoice', 'Delete Invoice', Icons.receipt_long_outlined),
    const MenuEntry('payments', 'Payments', Icons.payments_outlined),
    const MenuEntry(
      'payroll_accounts',
      'Payroll & Accounts',
      Icons.account_balance_wallet_outlined,
      children: [
        MenuEntry('expenses', 'Expenses', Icons.receipt_outlined),
        MenuEntry('accounting_system', 'Accounting System',
            Icons.calculate_outlined),
        MenuEntry(
            'balance_sheet', 'Balance Sheet', Icons.balance_outlined),
        MenuEntry('generate_salary', 'Generate Salary',
            Icons.add_card_outlined),
        MenuEntry(
            'salary_sheet', 'Salary Sheet', Icons.list_alt_outlined),
        MenuEntry('attendance', 'Attendance', Icons.fact_check_outlined),
      ],
    ),
    const MenuEntry('settings', 'Settings', Icons.settings_outlined),
  ];

  MenuEntry? _findEntry(String key, [List<MenuEntry>? list]) {
    for (final entry in (list ?? _menu)) {
      if (entry.key == key) return entry;
      if (entry.children != null) {
        final found = _findEntry(key, entry.children);
        if (found != null) return found;
      }
    }
    return null;
  }

  String get _selectedTitle => _findEntry(selectedKey)?.title ?? '';

  void _select(String key) {
    setState(() => selectedKey = key);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return Scaffold(
            backgroundColor: background,
            drawer: Drawer(
              backgroundColor: navy,
              child: SafeArea(child: _buildSidebar(forceExpanded: true)),
            ),
            appBar: _buildMobileAppBar(),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildBody(),
            ),
          );
        }

        return Scaffold(
          backgroundColor: background,
          body: Row(
            children: [
              _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildBody(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= BRANCH SELECTOR (top of every admin screen) =================

  Widget _branchSelector({bool compact = false}) {
    return StreamBuilder<List<Branch>>(
      stream: _branchService.streamBranches(),
      builder: (context, snapshot) {
        final branches = snapshot.data ?? [];

        return ValueListenableBuilder<String?>(
          valueListenable: selectedBranchId,
          builder: (context, currentId, _) {
            return Container(
              constraints: BoxConstraints(maxWidth: compact ? 160 : 220),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: compact ? Colors.blue : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: compact
                    ? null
                    : Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: currentId,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down,
                      color: compact ? Colors.white : Colors.black54,
                      size: 18),
                  style: TextStyle(
                    color: compact ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  dropdownColor: Colors.white,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Branches',
                          style: TextStyle(color: Colors.black87)),
                    ),
                    ...branches.map((b) => DropdownMenuItem<String?>(
                      value: b.id,
                      child: Text(b.name,
                          style: const TextStyle(color: Colors.black87)),
                    )),
                  ],
                  onChanged: (v) {
                    final name = v == null
                        ? null
                        : branches.firstWhere((b) => b.id == v).name;
                    setSelectedBranch(v, name);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================= MOBILE APP BAR =================

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: navy,
      foregroundColor: Colors.white,
      title: Text(_selectedTitle),
      actions: [
        _branchSelector(compact: true),
        const SizedBox(width: 10),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseAuth.instance.currentUser == null
              ? const Stream.empty()
              : _userService
              .streamUserProfile(FirebaseAuth.instance.currentUser!.uid),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            return ProfileAvatar(
              uid: FirebaseAuth.instance.currentUser?.uid ?? '',
              photoUrl: data?['photoUrl'],
              radius: 16,
            );
          },
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ================= SIDEBAR =================

  Widget _buildSidebar({bool forceExpanded = false}) {
    final collapsed = forceExpanded ? false : sidebarCollapsed;
    final width = collapsed ? 85.0 : 250.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: width,
      color: navy,
      child: Column(
        children: [
          const SizedBox(height: 25),
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/marketing.jpg',
                width: 164,
                height: 164,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.apartment_rounded,
                    size: 65,
                    color: Color(0xFF0D6EFD),
                  );
                },
              ),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 12),
            const Text(
              kCompanyName,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              kAppTagline,
              style: TextStyle(
                  color: Colors.white60, fontSize: 10, letterSpacing: 1),
            ),
          ],
          const SizedBox(height: 30),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _menu
                  .map((entry) => _buildMenuNode(
                entry,
                collapsed: collapsed,
                forceExpanded: forceExpanded,
                depth: 0,
              ))
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 19),
                label: collapsed ? const SizedBox() : const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuNode(
      MenuEntry entry, {
        required bool collapsed,
        required bool forceExpanded,
        required int depth,
      }) {
    final hasChildren = entry.children != null && entry.children!.isNotEmpty;
    final isGroupExpanded = _expandedGroups.contains(entry.key);
    final selected = selectedKey == entry.key;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: selected ? Colors.white.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (hasChildren) {
              setState(() {
                if (isGroupExpanded) {
                  _expandedGroups.remove(entry.key);
                } else {
                  _expandedGroups.add(entry.key);
                }
              });
            } else {
              _select(entry.key);
              if (forceExpanded) {
                Navigator.of(context).maybePop();
              }
            }
          },
          child: Container(
            height: 48,
            padding: EdgeInsets.only(left: 14 + (depth * 18), right: 14),
            child: Row(
              children: [
                Icon(entry.icon,
                    color: selected ? Colors.white : Colors.white70,
                    size: depth > 0 ? 18 : 21),
                if (!collapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      entry.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: depth > 0 ? 13 : 14,
                        fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (hasChildren)
                    Icon(
                      isGroupExpanded
                          ? Icons.expand_more
                          : Icons.chevron_right,
                      color: Colors.white54,
                      size: 18,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (!hasChildren) return row;

    return Column(
      children: [
        row,
        if (isGroupExpanded && !collapsed)
          ...entry.children!.map((child) => _buildMenuNode(
            child,
            collapsed: collapsed,
            forceExpanded: forceExpanded,
            depth: depth + 1,
          )),
      ],
    );
  }

  // ================= TOP BAR =================

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 8)],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Toggle Sidebar',
            onPressed: () =>
                setState(() => sidebarCollapsed = !sidebarCollapsed),
            icon: const Icon(Icons.menu),
          ),
          const SizedBox(width: 12),
          Text(
            _selectedTitle,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          _branchSelector(),
          const SizedBox(width: 20),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 17, color: blue),
              const SizedBox(width: 7),
              Text(_currentDate(), style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 25),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_outlined),
          ),
          const SizedBox(width: 8),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseAuth.instance.currentUser == null
                ? const Stream.empty()
                : _userService
                .streamUserProfile(FirebaseAuth.instance.currentUser!.uid),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              return ProfileAvatar(
                uid: FirebaseAuth.instance.currentUser?.uid ?? '',
                photoUrl: data?['photoUrl'],
                radius: 19,
              );
            },
          ),
          const SizedBox(width: 10),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Admin',
                  style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Administrator',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ================= BODY ROUTER =================

  Widget _buildBody() {
    switch (selectedKey) {
      case 'dashboard':
        return _buildDashboard();
      case 'items':
        return const ProductsScreen();
      case 'categories':
        return const CategoriesScreen();
      case 'raw_materials':
        return const RawMaterialsScreen();
      case 'brands':
        return const BrandsScreen();
      case 'stock_adjustment':
        return const InventoryScreen();
      case 'employees':
        return const EmployeesScreen();
      case 'parties':
        return const PartiesScreen();
      case 'areas':
        return const AreasScreen();
      case 'expenses':
        return const ExpensesScreen();
      case 'accounting_system':
        return const AccountingSystemScreen();
      case 'balance_sheet':
        return const BalanceSheetScreen();
      case 'generate_salary':
        return const GenerateSalaryScreen();
      case 'salary_sheet':
        return const SalarySheetScreen();
      case 'attendance':
        return const AttendanceScreen();
      case 'branches':
        return const BranchesScreen();
      case 'purchases':
        return const PurchasesScreen();
      case 'delete_invoice':
        return const DeleteInvoiceScreen();
      case 'payments':
        return const PaymentsScreen();
      case 'reports':
        return const ReportsScreen();
      case 'invoices_report':
        return const InvoicesReportScreen();
      case 'stock_audit':
        return const StockAuditScreen();
      case 'stock_report':
        return const StockReportScreen();
      case 'parties_report':
        return const PartiesReportScreen();
      case 'settings':
        return const SettingsScreen();
      default:
        return _comingSoon(_selectedTitle);
    }
  }

  Widget _comingSoon(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.construction_outlined,
                size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('$title — Coming Soon',
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('This module is under development.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ================= DASHBOARD =================

  Widget _buildDashboard() {
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
              style:
              const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
            _statCardStream(
              title: 'Stock',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF299FB0),
              stream: _productService.streamProducts().map((list) =>
                  list.fold<double>(0, (sum, p) => sum + p.currentStock)),
            ),
            _statCardStream(
              title: 'Sales',
              icon: Icons.point_of_sale_outlined,
              color: const Color(0xFF3159C9),
              stream: _saleService.streamSales().map((list) =>
                  list.fold<double>(0, (sum, s) => sum + s.totalAmount)),
            ),
            _statCardStream(
              title: 'Purchase',
              icon: Icons.shopping_bag_outlined,
              color: const Color(0xFF16A673),
              stream: _purchaseService.streamPurchases().map((list) =>
                  list.fold<double>(0, (sum, p) => sum + p.totalAmount)),
            ),
            _statCardStream(
              title: 'Receivable',
              icon: Icons.person_add_alt_1_outlined,
              color: const Color(0xFFE8A900),
              stream: _customerService.streamCustomers().map((list) =>
                  list.fold<double>(0, (sum, c) => sum + c.totalReceivable)),
            ),
            _statCardStream(
              title: 'Payable',
              icon: Icons.person_remove_outlined,
              color: const Color(0xFFD9362F),
              stream: _supplierService.streamSuppliers().map((list) =>
                  list.fold<double>(0, (sum, s) => sum + s.totalPayable)),
            ),
            _statCardStream(
              title: 'Customers',
              icon: Icons.people_outline,
              color: const Color(0xFFE8A900),
              stream: _customerService
                  .streamCustomers()
                  .map((list) => list.length.toDouble()),
              isCount: true,
            ),
            _statCardStream(
              title: 'Suppliers',
              icon: Icons.local_shipping_outlined,
              color: const Color(0xFF7B61C9),
              stream: _supplierService
                  .streamSuppliers()
                  .map((list) => list.length.toDouble()),
              isCount: true,
            ),
            _statCardStream(
              title: 'Employees',
              icon: Icons.badge_outlined,
              color: const Color(0xFF299FB0),
              stream: _employeeService
                  .streamEmployees()
                  .map((list) => list.length.toDouble()),
              isCount: true,
            ),
          ],
        ),
        const SizedBox(height: 25),
        LayoutBuilder(
          builder: (context, constraints) {
            final stackVertically = constraints.maxWidth < 700;
            if (stackVertically) {
              return Column(
                children: [
                  _buildSalesOverview(),
                  const SizedBox(height: 20),
                  _buildQuickActions(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildSalesOverview()),
                const SizedBox(width: 20),
                Expanded(child: _buildQuickActions()),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _buildRecentActivity(),
      ],
    );
  }

  Widget _statCardStream({
    required String title,
    required IconData icon,
    required Color color,
    required Stream<double> stream,
    bool isCount = false,
  }) {
    return StreamBuilder<double>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;
        final display =
        isCount ? value.toInt().toString() : value.toStringAsFixed(0);
        return _statCard(title: title, value: display, icon: icon, color: color);
      },
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
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
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesOverview() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text('Monthly sales performance',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          Expanded(
            child: Center(
              child: Icon(Icons.bar_chart_rounded,
                  size: 90, color: blue.withOpacity(0.25)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          _quickAction('Add Product', Icons.add_box_outlined, onTap: () {
            setState(() => _expandedGroups.add('inventory_group'));
            _select('items');
          }),
          _quickAction('New Purchase', Icons.shopping_cart_outlined,
              onTap: () => _select('purchases')),
          _quickAction('Add Customer', Icons.person_add_outlined, onTap: () {
            setState(() => _expandedGroups.add('administration'));
            _select('parties');
          }),
        ],
      ),
    );
  }

  Widget _quickAction(String title, IconData icon, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 43,
        child: OutlinedButton.icon(
          onPressed: onTap ?? () {},
          icon: Icon(icon, size: 19),
          label: Text(title),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Center(
            child: Padding(
              padding: EdgeInsets.all(25),
              child: Text('No recent activity',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _authService.logout();
  }

  String _currentDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}