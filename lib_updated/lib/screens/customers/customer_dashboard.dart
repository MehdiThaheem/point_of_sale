import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/employee.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../services/user_service.dart';
import '../../widgets/profile_avatar.dart';
import '../admin/admin_dashboard.dart' show kCompanyName, kAppTagline;
import 'counter_sale_screen.dart';
import 'quick_sale_screen.dart';

// The Counter Sale staff dashboard. A cut-down shell (same branded look
// as the Manager/Admin dashboards) with exactly two sections: the POS-
// style "Counter Sale" screen and the simpler named-party "Sale" form.
// Both save into the same `sales` collection Admin already reads from,
// so every sale made here shows up in Admin's Sales/Reports immediately.
class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final EmployeeService _employeeService = EmployeeService();

  String selectedKey = 'counter_sale';
  bool sidebarCollapsed = false;

  final Color navy = const Color(0xFF03213D);
  final Color blue = const Color(0xFF3159C9);
  final Color background = const Color(0xFFF5F7FA);

  static const _menu = [
    ('counter_sale', 'Counter Sale', Icons.point_of_sale_outlined),
    ('sale', 'Sale', Icons.receipt_long_outlined),
  ];

  String get _selectedTitle =>
      _menu.firstWhere((e) => e.$1 == selectedKey).$2;

  Future<void> _logout() async {
    await _authService.logout();
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
            appBar: AppBar(
              backgroundColor: navy,
              foregroundColor: Colors.white,
              title: Text(_selectedTitle),
            ),
            body: _buildBody(),
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
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
              final name = data?['name'] as String? ?? 'Counter Sale';
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
                        'COUNTER SALE',
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
              children: _menu.map((entry) {
                final selected = selectedKey == entry.$1;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  child: Material(
                    color: selected
                        ? Colors.white.withOpacity(0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() => selectedKey = entry.$1);
                        if (forceExpanded) Navigator.of(context).maybePop();
                      },
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Icon(entry.$3,
                                color: selected
                                    ? Colors.white
                                    : Colors.white70,
                                size: 21),
                            if (!collapsed) ...[
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  entry.$2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
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

  // ================= TOP BAR =================

  Widget _buildTopBar() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: navy,
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 8)],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Toggle Sidebar',
            color: Colors.white,
            onPressed: () =>
                setState(() => sidebarCollapsed = !sidebarCollapsed),
            icon: const Icon(Icons.menu),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.storefront_outlined, color: Colors.white),
          const SizedBox(width: 10),
          // The branch name comes from this account's Employee record
          // (every account type gets one — see Add Employee), so it
          // always reflects which branch this counter belongs to.
          StreamBuilder<Employee?>(
            stream: uid.isEmpty
                ? const Stream.empty()
                : _employeeService.streamEmployeeByUid(uid),
            builder: (context, snapshot) {
              final branch = snapshot.data?.branchName ?? '';
              return Text(
                branch.isEmpty ? kCompanyName : branch.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= BODY ROUTER =================

  Widget _buildBody() {
    switch (selectedKey) {
      case 'sale':
        return const QuickSaleScreen();
      case 'counter_sale':
      default:
        return const CounterSaleScreen();
    }
  }
}