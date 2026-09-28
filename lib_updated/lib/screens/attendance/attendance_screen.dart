import 'package:flutter/material.dart';
import '../../models/attendance_record.dart';
import '../../models/employee.dart';
import '../../services/attendance_service.dart';
import '../../services/employee_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EmployeeService _employeeService = EmployeeService();
  final AttendanceService _attendanceService = AttendanceService();

  DateTime _selectedDate = DateTime.now();

  String get _dateKey =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _mark(Employee employee, String status) async {
    try {
      await _attendanceService.markAttendance(AttendanceRecord(
        id: '',
        employeeId: employee.id,
        employeeName: employee.name,
        dateKey: _dateKey,
        status: status,
      ));
    } catch (e) {
      // Previously this failure was silent — the tap looked like it did
      // nothing and nobody could tell why. Now the real Firestore error
      // (permission-denied, missing index, offline, etc.) is shown so it
      // can actually be diagnosed.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save attendance: $e')),
        );
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'leave':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Mark daily attendance and review history.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'Mark Attendance'),
              Tab(text: 'History'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMarkTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarkTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 10),
                Text(_dateKey, style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                const Icon(Icons.edit_calendar_outlined, size: 18, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<Employee>>(
            stream: _employeeService.streamEmployees(),
            builder: (context, employeeSnapshot) {
              final employees = employeeSnapshot.data ?? [];

              if (employees.isEmpty) {
                return const Center(
                  child: Text('No employees yet.',
                      style: TextStyle(color: Colors.grey)),
                );
              }

              return StreamBuilder<List<AttendanceRecord>>(
                stream: _attendanceService.streamAttendanceForDate(_dateKey),
                builder: (context, attendanceSnapshot) {
                  if (attendanceSnapshot.hasError) {
                    // A silent stream error (e.g. Firestore permission
                    // denied) used to just show an empty/unmarked list
                    // with no clue why. This makes the real reason visible.
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Could not load attendance:\n${attendanceSnapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final records = attendanceSnapshot.data ?? [];
                  final statusFor = {
                    for (final r in records) r.employeeId: r.status,
                  };

                  return ListView.builder(
                    itemCount: employees.length,
                    itemBuilder: (context, index) {
                      final employee = employees[index];
                      final status = statusFor[employee.id];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(employee.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              _statusChip('Present', 'present', status,
                                      () => _mark(employee, 'present')),
                              const SizedBox(width: 6),
                              _statusChip('Absent', 'absent', status,
                                      () => _mark(employee, 'absent')),
                              const SizedBox(width: 6),
                              _statusChip('Leave', 'leave', status,
                                      () => _mark(employee, 'leave')),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statusChip(
      String label, String value, String? current, VoidCallback onTap) {
    final selected = current == value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? _statusColor(value).withOpacity(0.15)
              : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _statusColor(value) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? _statusColor(value) : Colors.grey,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<Employee>>(
      stream: _employeeService.streamEmployees(),
      builder: (context, employeeSnapshot) {
        final employees = employeeSnapshot.data ?? [];

        if (employees.isEmpty) {
          return const Center(
            child: Text('No employees yet.', style: TextStyle(color: Colors.grey)),
          );
        }

        return DefaultTabController(
          length: employees.length,
          child: Column(
            children: [
              TabBar(
                isScrollable: true,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                tabs: employees.map((e) => Tab(text: e.name)).toList(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: employees.map((employee) {
                    return StreamBuilder<List<AttendanceRecord>>(
                      stream: _attendanceService
                          .streamAttendanceForEmployee(employee.id),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          // This query filters by employeeId AND orders by
                          // dateKey, which Firestore requires a composite
                          // index for. Without it, the stream throws a
                          // "failed-precondition" error with a direct link
                          // to create the index — but the old code only
                          // ever looked at snapshot.data, so that error
                          // was swallowed and the screen just showed
                          // "No attendance records yet" even when records
                          // existed. This surfaces it instead.
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Could not load history:\n${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        final records = snapshot.data ?? [];

                        if (records.isEmpty) {
                          return const Center(
                            child: Text('No attendance records yet.',
                                style: TextStyle(color: Colors.grey)),
                          );
                        }

                        final presentCount =
                            records.where((r) => r.status == 'present').length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 8),
                              child: Text(
                                'Present: $presentCount / ${records.length} days',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: records.length,
                                itemBuilder: (context, index) {
                                  final record = records[index];
                                  return ListTile(
                                    leading: Icon(Icons.circle,
                                        size: 12,
                                        color:
                                        _statusColor(record.status)),
                                    title: Text(record.dateKey),
                                    trailing: Text(
                                      record.status.toUpperCase(),
                                      style: TextStyle(
                                        color: _statusColor(record.status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}