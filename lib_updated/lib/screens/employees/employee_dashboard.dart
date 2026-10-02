import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/employee.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../services/user_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/profile_avatar.dart';
import '../admin/dashboard_home.dart';
import '../areas/areas_screen.dart';
import '../parties/parties_screen.dart';
import '../reports/invoices_report_screen.dart';
import '../reports/parties_report_screen.dart';
import '../reports/reports_screen.dart';
import '../reports/stock_audit_screen.dart';
import '../reports/stock_report_screen.dart';
import 'employees_admin_screen.dart';

// A single sidebar entry, same shape as AdminDashboard's — kept local so
// this screen has no other dependency on the admin file besides the two
// branding constants above.
class _MenuEntry {
  final String key;
  final String title;
  final IconData icon;
  final List<_MenuEntry>? children;

  const _MenuEntry(this.key, this.title, this.icon, {this.children});
}

// The Manager's dashboard. Deliberately a cut-down version of
// AdminDashboard — same look, same Administration/Reports screens (the
// exact same widgets an Admin uses), but only 3 sections are reachable,
// and the top bar shows the Manager's own branch instead of a branch
// switcher.
class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});

  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final EmployeeService _employeeService = EmployeeService();

  // The Manager's own Employee record. Until it has loaded we show a
  // spinner (so no "All Branches" data can flash on screen), then the whole
  // app is locked to this Manager's branch.
  Employee? _me;
  bool _meLoaded = false;
  StreamSubscription? _meSub;

  String selectedKey = 'dashboard';
  bool sidebarCollapsed = false;
  final Set<String> _expandedGroups = {};

  final Color navy = const Color(0xFF03213D);
  final Color blue = const Color(0xFF3159C9);
  final Color background = const Color(0xFFF5F7FA);

  static const List<_MenuEntry> _menu = [
    _MenuEntry('dashboard', 'Dashboard', Icons.dashboard_outlined),
    _MenuEntry(
      'administration',
      'Administration',
      Icons.admin_panel_settings_outlined,
      children: [
        _MenuEntry('employees', 'Employee', Icons.badge_outlined),
        _MenuEntry('parties', 'Parties', Icons.groups_outlined),
        _MenuEntry('areas', 'Areas', Icons.map_outlined),
      ],
    ),
    _MenuEntry(
      'reports',
      'Reports',
      Icons.bar_chart_outlined,
      children: [
        _MenuEntry('invoices_report', 'Invoices Report',
            Icons.receipt_long_outlined),
        _MenuEntry('stock_audit', 'Stock Audit', Icons.fact_check_outlined),
        _MenuEntry(
            'stock_report', 'Stock Report', Icons.inventory_outlined),
        _MenuEntry(
            'parties_report', 'Parties Report', Icons.groups_outlined),
      ],
    ),
  ];

  _MenuEntry? _findEntry(String key, [List<_MenuEntry>? list]) {
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

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      _meLoaded = true;
      return;
    }
    _meSub = _employeeService.streamEmployeeByUid(uid).listen((e) {
      if (!mounted) return;
      setState(() {
        _me = e;
        _meLoaded = true;
      });
      if (e != null && e.branchId.isNotEmpty) {
        // Every screen filters by this, so the Manager only ever sees (and
        // creates) data for their own branch.
        lockToBranch(e.branchId, e.branchName);
      } else {
        unlockBranch();
      }
    }, onError: (_) {
      if (mounted) setState(() => _meLoaded = true);
    });
  }

  @override
  void dispose() {
    _meSub?.cancel();
    super.dispose();
  }

  void _select(String key) {
    setState(() => selectedKey = key);
  }

  Future<void> _logout() async {
    unlockBranch(); // next login (e.g. an Admin) starts on "All Branches"
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

  // ================= MOBILE APP BAR =================

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: navy,
      foregroundColor: Colors.white,
      title: Text(_selectedTitle),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_outlined),
        ),
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final collapsed = forceExpanded ? false : sidebarCollapsed;
    final width = collapsed ? 85.0 : 250.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: width,
      color: navy,
      child: Column(
        children: [
          const SizedBox(height: 20),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: uid.isEmpty
                ? const Stream.empty()
                : _userService.streamUserProfile(uid),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              final name = data?['name'] as String? ?? 'Manager';
              return Column(
                children: [
                  ProfileAvatar(
                    uid: uid,
                    photoUrl: data?['photoUrl'],
                    radius: collapsed ? 24 : 38,
                  ),
                  if (!collapsed) ...[
                    const SizedBox(height: 10),
                    Text(
                      name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8A900),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'MANAGER',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 25),
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
      _MenuEntry entry, {
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
                Icon(
                  entry.icon,
                  color: selected ? Colors.white : Colors.white70,
                  size: depth > 0 ? 18 : 21,
                ),
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
          // Shows which branch this Manager belongs to — a fixed label,
          // not a switcher, since a Manager only ever sees their own
          // branch (unlike Admin's "All Branches" picker).
          StreamBuilder<Employee?>(
            stream: uid.isEmpty
                ? const Stream.empty()
                : _employeeService.streamEmployeeByUid(uid),
            builder: (context, snapshot) {
              final branch = snapshot.data?.branchName ?? '';
              if (branch.isEmpty) return const SizedBox();
              return Container(
                margin: const EdgeInsets.only(right: 20),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.store_outlined, size: 16, color: blue),
                    const SizedBox(width: 6),
                    Text(branch,
                        style: TextStyle(
                            color: blue, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          ),
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
            stream: uid.isEmpty
                ? const Stream.empty()
                : _userService.streamUserProfile(uid),
            builder: (context, snapshot) {
              final data = snapshot.data?.data();
              return ProfileAvatar(
                uid: uid,
                photoUrl: data?['photoUrl'],
                radius: 19,
              );
            },
          ),
          const SizedBox(width: 10),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: uid.isEmpty
                ? const Stream.empty()
                : _userService.streamUserProfile(uid),
            builder: (context, snapshot) {
              final name = snapshot.data?.data()?['name'] as String?;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (name != null && name.isNotEmpty) ? name : 'Manager',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Text('Manager',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= BODY ROUTER =================

  Widget _buildBody() {
    if (!_meLoaded) {
      return const Padding(
        padding: EdgeInsets.all(60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final me = _me;
    if (me == null || me.branchId.isEmpty) return _noBranch();
    return _buildBodyInner();
  }

  Widget _noBranch() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10)],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_mall_directory_outlined,
                size: 48, color: Color(0xFFE67E00)),
            SizedBox(height: 14),
            Text('No branch assigned',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              'Your account is not linked to a branch yet, so no data can be '
                  'shown. Please ask the admin to set your branch on your '
                  'Employee record.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyInner() {
    switch (selectedKey) {
      case 'dashboard':
        return _buildDashboard();
      case 'employees':
        return const EmployeesScreen();
      case 'parties':
        return const PartiesScreen();
      case 'areas':
        return const AreasScreen();
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
      default:
        return const SizedBox();
    }
  }

  // ================= DASHBOARD =================

  // Same dashboard as the Admin's (cards, sales chart, recent activity), but
  // it only ever shows this Manager's branch because the app is locked to it.
  Widget _buildDashboard() {
    return const DashboardHome(roleLabel: 'Manager');
  }
}