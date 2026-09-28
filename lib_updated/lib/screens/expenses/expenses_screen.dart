import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/expense.dart';
import '../../models/expense_account.dart';
import '../../models/expense_head.dart';
import '../../services/expense_account_service.dart';
import '../../services/expense_head_service.dart';
import '../../services/expense_service.dart';
import '../../utils/branch_filter.dart';
import '../../widgets/confirm_dialog.dart';

class _Palette {
  static const blue = Color(0xFF2F5FDE);
  static const green = Color(0xFF12A150);
  static const red = Color(0xFFE5484D);
  static const bg = Color(0xFFF4F6FA);
  static const cardBorder = Color(0xFFE7EAF0);
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final ExpenseService _service = ExpenseService();
  final ExpenseHeadService _headService = ExpenseHeadService();
  final ExpenseAccountService _accountService = ExpenseAccountService();

  // ---- Add New Expense form state ----
  DateTime _formDate = DateTime.now();
  ExpenseHead? _formHead;
  ExpenseAccount? _formAccount;
  String _formCashBank = 'Cash in Hand';
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // ---- Filter bar state ----
  DateTime _filterStart =
  DateTime.now().subtract(const Duration(days: 21));
  DateTime _filterEnd = DateTime.now();
  ExpenseHead? _filterHead;
  ExpenseAccount? _filterAccount;

  static const cashBankOptions = ['Cash in Hand', 'Bank Account'];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_formHead == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an Expense Head.')),
      );
      return;
    }
    if (selectedBranchId.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Select a branch from the top bar before adding an expense.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.addExpense(Expense(
        id: '',
        branchId: selectedBranchId.value ?? '',
        branchName: selectedBranchName.value ?? '',
        expenseHeadId: _formHead!.id,
        expenseHeadName: _formHead!.name,
        expenseAccountId: _formAccount?.id ?? '',
        expenseAccountName: _formAccount?.name ?? '',
        cashBankAccount: _formCashBank,
        amount: double.tryParse(_amountController.text.trim()) ?? 0,
        description: _descriptionController.text.trim(),
        date: Timestamp.fromDate(_formDate),
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: _Palette.green,
              content: Text('Expense saved.')),
        );
        setState(() {
          _formDate = DateTime.now();
          _formHead = null;
          _formAccount = null;
          _formCashBank = 'Cash in Hand';
          _amountController.text = '';
          _descriptionController.clear();
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

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Expense',
      message: 'Delete this expense of ${expense.amount.toStringAsFixed(0)}?',
    );
    if (confirmed) {
      await _service.deleteExpense(expense.id);
    }
  }

  void _quickAddDialog({
    required String title,
    required String hint,
    required Future<void> Function(String name) onAdd,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.blue, foregroundColor: Colors.white),
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                await onAdd(controller.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Could not add: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Palette.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;
              final formPanel = _buildAddExpenseForm();
              final listPanel = _buildExpenseList();

              if (stacked) {
                return Column(
                  children: [
                    formPanel,
                    const SizedBox(height: 16),
                    listPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 380, child: formPanel),
                  const SizedBox(width: 16),
                  Expanded(child: listPanel),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Expense Management',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            ValueListenableBuilder<String?>(
              valueListenable: selectedBranchName,
              builder: (context, branchName, _) {
                return Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(branchName ?? 'All Branches',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                );
              },
            ),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: () => _quickAddDialog(
            title: 'Add Expense Head',
            hint: 'e.g. Rent, Utilities, Fuel',
            onAdd: (name) => _headService.addExpenseHead(name),
          ),
          style: OutlinedButton.styleFrom(foregroundColor: _Palette.blue),
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add Expense Head'),
        ),
        OutlinedButton.icon(
          onPressed: () => _quickAddDialog(
            title: 'Add Expense Account',
            hint: 'e.g. Office Rent Account',
            onAdd: (name) => _accountService.addExpenseAccount(name),
          ),
          style: OutlinedButton.styleFrom(foregroundColor: _Palette.green),
          icon: const Icon(Icons.add_circle_outline, size: 18),
          label: const Text('Add Expense Account'),
        ),
      ],
    );
  }

  // ================= ADD NEW EXPENSE (left panel) =================

  Widget _buildAddExpenseForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1B2B4B), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: _Palette.blue, size: 20),
                const SizedBox(width: 8),
                const Text('Add New Expense',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 18),
            _label('Date'),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _formDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _formDate = picked);
              },
              child: InputDecorator(
                decoration: _fieldDecoration(),
                child: Text(_formatDate(_formDate)),
              ),
            ),
            const SizedBox(height: 14),
            _label('Expense Head'),
            StreamBuilder<List<ExpenseHead>>(
              stream: _headService.streamExpenseHeads(),
              builder: (context, snapshot) {
                final heads = snapshot.data ?? [];
                return DropdownButtonFormField<ExpenseHead>(
                  value: _formHead,
                  isExpanded: true,
                  decoration: _fieldDecoration(hint: 'Select Category'),
                  items: heads
                      .map((h) =>
                      DropdownMenuItem(value: h, child: Text(h.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _formHead = v),
                );
              },
            ),
            const SizedBox(height: 14),
            _label('Expense Account (Dr)'),
            StreamBuilder<List<ExpenseAccount>>(
              stream: _accountService.streamExpenseAccounts(),
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? [];
                return DropdownButtonFormField<ExpenseAccount>(
                  value: _formAccount,
                  isExpanded: true,
                  decoration: _fieldDecoration(hint: '-- Choose Account --'),
                  items: accounts
                      .map((a) =>
                      DropdownMenuItem(value: a, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _formAccount = v),
                );
              },
            ),
            const SizedBox(height: 14),
            _label('Cash/Bank (Cr)'),
            DropdownButtonFormField<String>(
              value: _formCashBank,
              isExpanded: true,
              decoration: _fieldDecoration(),
              items: cashBankOptions
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _formCashBank = v ?? 'Cash in Hand'),
            ),
            const SizedBox(height: 14),
            _label('Amount'),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: _fieldDecoration(hint: '0.00'),
              validator: (v) => (v == null || double.tryParse(v.trim()) == null)
                  ? 'Enter a valid amount'
                  : null,
            ),
            const SizedBox(height: 14),
            _label('Description'),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: _fieldDecoration(hint: 'Reason for expense...'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _Palette.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Text('SAVE EXPENSE',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: _Palette.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  // ================= EXPENSE LIST (right panel) =================

  Widget _buildExpenseList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0F1B2B4B), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          const SizedBox(height: 16),
          ValueListenableBuilder<String?>(
            valueListenable: selectedBranchId,
            builder: (context, branchFilter, _) {
              return StreamBuilder<List<Expense>>(
                stream: _service.streamExpenses(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  var expenses = snapshot.data ?? [];
                  if (branchFilter != null) {
                    expenses = expenses
                        .where((e) => e.branchId == branchFilter)
                        .toList();
                  }
                  expenses = expenses.where((e) {
                    final d = e.date?.toDate();
                    if (d == null) return true;
                    final afterStart = !d.isBefore(
                        DateTime(_filterStart.year, _filterStart.month,
                            _filterStart.day));
                    final beforeEnd = !d.isAfter(DateTime(_filterEnd.year,
                        _filterEnd.month, _filterEnd.day, 23, 59, 59));
                    final headMatch =
                        _filterHead == null || e.expenseHeadId == _filterHead!.id;
                    final accountMatch = _filterAccount == null ||
                        e.expenseAccountId == _filterAccount!.id;
                    return afterStart && beforeEnd && headMatch && accountMatch;
                  }).toList();

                  final total =
                  expenses.fold<double>(0, (sum, e) => sum + e.amount);

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width < 900
                              ? MediaQuery.of(context).size.width - 64
                              : MediaQuery.of(context).size.width - 460),
                      child: DataTable(
                        headingRowColor:
                        MaterialStateProperty.all(const Color(0xFFF5F7FA)),
                        columns: const [
                          DataColumn(
                              label: Text('Date',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Account',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Description',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Amount',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Action',
                                  style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: [
                          if (expenses.isEmpty)
                            const DataRow(cells: [
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('No expenses found for this range.',
                                  style: TextStyle(color: Colors.grey))),
                              DataCell(Text('')),
                              DataCell(Text('')),
                            ])
                          else
                            ...expenses.asMap().entries.map((entry) {
                              final index = entry.key;
                              final expense = entry.value;
                              return DataRow(
                                color: index.isOdd
                                    ? MaterialStateProperty.all(
                                    const Color(0xFFFAFBFD))
                                    : null,
                                cells: [
                                  DataCell(
                                      Text(_formatDate(expense.date?.toDate()))),
                                  DataCell(Text(expense.expenseAccountName
                                      .isEmpty
                                      ? expense.expenseHeadName
                                      : expense.expenseAccountName)),
                                  DataCell(SizedBox(
                                    width: 200,
                                    child: Text(
                                      expense.description.isEmpty
                                          ? '-'
                                          : expense.description,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )),
                                  DataCell(Text(
                                    expense.amount.toStringAsFixed(0),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  )),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: _Palette.red, size: 18),
                                      onPressed: () => _deleteExpense(expense),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          DataRow(cells: [
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('TOTAL EXPENSES:',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(
                              total.toStringAsFixed(0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, color: _Palette.red),
                            )),
                            const DataCell(Text('')),
                          ]),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 160,
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _filterStart,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _filterStart = picked);
            },
            child: InputDecorator(
              decoration: _fieldDecoration(),
              child: Text(_formatDate(_filterStart)),
            ),
          ),
        ),
        SizedBox(
          width: 160,
          child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _filterEnd,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _filterEnd = picked);
            },
            child: InputDecorator(
              decoration: _fieldDecoration(),
              child: Text(_formatDate(_filterEnd)),
            ),
          ),
        ),
        SizedBox(
          width: 170,
          child: StreamBuilder<List<ExpenseHead>>(
            stream: _headService.streamExpenseHeads(),
            builder: (context, snapshot) {
              final heads = snapshot.data ?? [];
              return DropdownButtonFormField<ExpenseHead?>(
                value: _filterHead,
                isExpanded: true,
                decoration: _fieldDecoration(),
                items: [
                  const DropdownMenuItem<ExpenseHead?>(
                      value: null, child: Text('All Heads')),
                  ...heads.map(
                          (h) => DropdownMenuItem(value: h, child: Text(h.name))),
                ],
                onChanged: (v) => setState(() => _filterHead = v),
              );
            },
          ),
        ),
        SizedBox(
          width: 170,
          child: StreamBuilder<List<ExpenseAccount>>(
            stream: _accountService.streamExpenseAccounts(),
            builder: (context, snapshot) {
              final accounts = snapshot.data ?? [];
              return DropdownButtonFormField<ExpenseAccount?>(
                value: _filterAccount,
                isExpanded: true,
                decoration: _fieldDecoration(),
                items: [
                  const DropdownMenuItem<ExpenseAccount?>(
                      value: null, child: Text('All Accounts')),
                  ...accounts.map((a) =>
                      DropdownMenuItem(value: a, child: Text(a.name))),
                ],
                onChanged: (v) => setState(() => _filterAccount = v),
              );
            },
          ),
        ),
        SizedBox(
          height: 46,
          width: 46,
          child: ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Icon(Icons.search, size: 18),
          ),
        ),
      ],
    );
  }
}