import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/employee.dart';
import '../../models/salary_payment.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../services/salary_service.dart';
import '../../services/user_service.dart';
import '../../utils/auth_helpers.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/confirm_dialog.dart';
import 'employee_form_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

// Shared everywhere a portal access role needs a human-readable label —
// the Manage Account dropdown and the live badge in the staff table both
// use this so they can never say different things for the same role.
String roleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'employee':
      return 'Manager';
    case 'customer':
      return 'Counter Boy';
    case 'supplier':
      return 'Delivery Boy';
    default:
      return role;
  }
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final EmployeeService _service = EmployeeService();
  final SalaryService _salaryService = SalaryService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  static String _currentMonthLabel() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  Future<void> _openAdd() async {
    await showDialog(
      context: context,
      builder: (_) => const EmployeeFormScreen(),
    );
  }

  Future<void> _openEdit(Employee employee) async {
    await showDialog(
      context: context,
      builder: (_) => EmployeeFormScreen(employee: employee),
    );
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Employee',
      message: 'Are you sure you want to delete "${employee.name}"?',
    );
    if (confirmed) {
      await _service.deleteEmployee(employee.id);
    }
  }

  void _viewDetails(Employee employee) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(employee.name),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Designation', employee.position),
              _detailRow('Branch', employee.branchName),
              _detailRow('Phone', employee.phone),
              _detailRow('Username', displayUsername(employee.email)),
              _detailRow('CNIC', employee.cnic),
              _detailRow('Qualification', employee.qualification),
              _detailRow('Address', employee.address),
              _detailRow('Salary', employee.salary.toStringAsFixed(0)),
              _detailRow('Status', employee.status),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ================= MANAGE ACCOUNT (key icon) =================

  void _manageAccount(Employee employee) {
    if (employee.uid.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Linked Login'),
          content: Text(
              '"${employee.name}" does not have a portal login account yet. '
                  'Create one from Settings > Create Team Login.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final isInternal = isInternalAuthEmail(employee.email);
    String selectedRole = 'employee';
    bool sendingReset = false;

    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder(
        stream: _userService.streamUserProfile(employee.uid),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          selectedRole = data?['role'] ?? 'employee';

          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: Text('Manage Account — ${employee.name}'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Username',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        displayUsername(employee.email),
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Access Role',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'admin', child: Text(roleLabel('admin'))),
                        DropdownMenuItem(
                            value: 'employee',
                            child: Text(roleLabel('employee'))),
                        DropdownMenuItem(
                            value: 'customer',
                            child: Text(roleLabel('customer'))),
                        DropdownMenuItem(
                            value: 'supplier',
                            child: Text(roleLabel('supplier'))),
                      ],
                      onChanged: (v) async {
                        if (v == null) return;
                        setDialogState(() => selectedRole = v);
                        await _userService.updateRole(
                            uid: employee.uid, role: v);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Role updated.')),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Password',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (isInternal) ...[
                      const Text(
                        'This is a username-based account (no real email), '
                            'so a reset email cannot be delivered. Ask them to '
                            'open the ⋮ menu in their own dashboard and use '
                            '"Change Password" while logged in.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ] else ...[
                      const Text(
                        'A reset link will be emailed to this address.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: sendingReset
                              ? null
                              : () async {
                            setDialogState(() => sendingReset = true);
                            try {
                              await _authService
                                  .sendPasswordResetEmail(
                                  employee.email);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Password reset email sent.')),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            } finally {
                              setDialogState(() => sendingReset = false);
                            }
                          },
                          icon: sendingReset
                              ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                              : const Icon(Icons.mail_outline, size: 16),
                          label: const Text('Send Password Reset Email'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = _currentMonthLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: selectedBranchId,
          builder: (context, branchFilter, _) {
            return StreamBuilder<List<Employee>>(
              stream: _service.streamEmployees(),
              builder: (context, employeeSnapshot) {
                var employees = employeeSnapshot.data ?? [];
                if (branchFilter != null) {
                  employees =
                      employees.where((e) => e.branchId == branchFilter).toList();
                }
                final totalStaff = employees.length;
                final monthlySalary = employees
                    .where((e) => e.status == 'active')
                    .fold<double>(0, (sum, e) => sum + e.salary);
                final activeUsers =
                    employees.where((e) => e.uid.isNotEmpty).length;

                return StreamBuilder<List<SalaryPayment>>(
                  stream: _salaryService.streamSalaryPayments(),
                  builder: (context, salarySnapshot) {
                    final payments = salarySnapshot.data ?? [];

                    double pendingBalance = 0;
                    for (final e
                    in employees.where((e) => e.status == 'active')) {
                      final paidThisMonth = payments
                          .where((p) =>
                      p.employeeId == e.id && p.month == currentMonth)
                          .fold<double>(0, (sum, p) => sum + p.amount);
                      final due = e.salary - paidThisMonth;
                      if (due > 0) pendingBalance += due;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GridView(
                          gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.5,
                          ),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _statCard('TOTAL STAFF', totalStaff.toString(),
                                const Color(0xFF3159C9)),
                            _statCard(
                                'MONTHLY SALARY',
                                monthlySalary.toStringAsFixed(0),
                                const Color(0xFF16A673)),
                            _statCard(
                                'PENDING BALANCE',
                                pendingBalance.toStringAsFixed(0),
                                const Color(0xFFD9362F)),
                            _statCard('ACTIVE USERS', activeUsers.toString(),
                                const Color(0xFFE8A900)),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            const Icon(Icons.people_alt_outlined,
                                color: Color(0xFF3159C9)),
                            const SizedBox(width: 8),
                            const Text(
                              'Staff Directory',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: _openAdd,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3159C9),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Employee'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (employees.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'No employees yet. Tap "Add Employee" to create one.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          _buildDirectoryTable(employees, payments, currentMonth),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _statCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
                color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryTable(List<Employee> employees,
      List<SalaryPayment> payments, String currentMonth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMinHeight: 64,
          dataRowMaxHeight: 76,
          headingRowColor:
          MaterialStateProperty.all(const Color(0xFFF5F7FA)),
          columns: const [
            DataColumn(label: Text('Photo')),
            DataColumn(label: Text('Name & Access')),
            DataColumn(label: Text('Access Role')),
            DataColumn(label: Text('Salary')),
            DataColumn(label: Text('Balance')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: employees.map((employee) {
            final paidThisMonth = payments
                .where((p) =>
            p.employeeId == employee.id && p.month == currentMonth)
                .fold<double>(0, (sum, p) => sum + p.amount);
            final balance = (employee.salary - paidThisMonth)
                .clamp(0, double.infinity);

            return DataRow(cells: [
              DataCell(
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: employee.photoUrl.isNotEmpty
                      ? NetworkImage(employee.photoUrl)
                      : null,
                  child: employee.photoUrl.isEmpty
                      ? const Icon(Icons.person_outline,
                      size: 18, color: Colors.grey)
                      : null,
                ),
              ),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(employee.name,
                        style:
                        const TextStyle(fontWeight: FontWeight.w700)),
                    if (employee.uid.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '@${displayUsername(employee.email)}',
                          style: const TextStyle(
                              color: Colors.green, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Single badge: the portal Access Role that admin
                    // assigns via Manage Account (the key icon), kept
                    // live via a stream on the user's own profile doc.
                    // The separate "Designation" text field is no longer
                    // shown here since it duplicated/conflicted with this.
                    if (employee.uid.isNotEmpty)
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _userService.streamUserProfile(employee.uid),
                        builder: (context, snapshot) {
                          final role = snapshot.data?.data()?['role'];
                          if (role == null) {
                            return const Text('-',
                                style: TextStyle(color: Colors.grey));
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3159C9)
                                  .withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: const Color(0xFF3159C9)
                                      .withOpacity(0.4)),
                            ),
                            child: Text(
                              roleLabel(role),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3159C9),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      const Text('-', style: TextStyle(color: Colors.grey)),
                    if (employee.branchName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          employee.branchName,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              DataCell(Text(employee.salary.toStringAsFixed(0))),
              DataCell(
                Text(
                  balance.toStringAsFixed(0),
                  style: TextStyle(
                      color: balance > 0 ? Colors.red : Colors.grey,
                      fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: employee.status == 'active'
                        ? Colors.green.withOpacity(0.12)
                        : Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    employee.status == 'active' ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: employee.status == 'active'
                          ? Colors.green
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye_outlined,
                          size: 18, color: Colors.blue),
                      onPressed: () => _viewDetails(employee),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Color(0xFF3159C9)),
                      onPressed: () => _openEdit(employee),
                    ),
                    IconButton(
                      icon: const Icon(Icons.vpn_key_outlined,
                          size: 18, color: Colors.amber),
                      onPressed: () => _manageAccount(employee),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.redAccent),
                      onPressed: () => _deleteEmployee(employee),
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}