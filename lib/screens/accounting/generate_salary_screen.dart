import 'package:flutter/material.dart';
import '../../models/employee.dart';
import '../../models/salary_payment.dart';
import '../../services/employee_service.dart';
import '../../services/salary_service.dart';

class GenerateSalaryScreen extends StatefulWidget {
  const GenerateSalaryScreen({super.key});

  @override
  State<GenerateSalaryScreen> createState() => _GenerateSalaryScreenState();
}

class _GenerateSalaryScreenState extends State<GenerateSalaryScreen> {
  final EmployeeService _employeeService = EmployeeService();
  final SalaryService _salaryService = SalaryService();

  Employee? _selectedEmployee;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedMonth = _currentMonthLabel();
  bool _saving = false;

  static String _currentMonthLabel() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  static List<String> _lastTwelveMonths() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return List.generate(12, (i) {
      final date = DateTime(now.year, now.month - i, 1);
      return '${months[date.month - 1]} ${date.year}';
    });
  }

  Future<void> _generate() async {
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an employee.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _salaryService.generateSalary(SalaryPayment(
        id: '',
        employeeId: _selectedEmployee!.id,
        employeeName: _selectedEmployee!.name,
        month: _selectedMonth,
        amount: amount,
        notes: _notesController.text.trim(),
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Salary generated for ${_selectedEmployee!.name}.')),
        );
        setState(() {
          _selectedEmployee = null;
          _amountController.clear();
          _notesController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = _lastTwelveMonths();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Generate Salary',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Record a salary payment for an employee.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: StreamBuilder<List<Employee>>(
            stream: _employeeService.streamEmployees(),
            builder: (context, snapshot) {
              final employees = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<Employee>(
                    value: employees.any((e) => e.id == _selectedEmployee?.id)
                        ? _selectedEmployee
                        : null,
                    decoration: const InputDecoration(labelText: 'Employee'),
                    items: employees
                        .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.name),
                    ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedEmployee = v;
                        if (v != null && v.salary > 0) {
                          _amountController.text = v.salary.toString();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: months
                        .map((m) =>
                        DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedMonth = v ?? _selectedMonth),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _generate,
                      child: _saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                        CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Generate Salary'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}