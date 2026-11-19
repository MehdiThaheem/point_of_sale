import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/branch.dart';
import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../models/sales.dart';
import '../../services/branch_service.dart';
import '../../services/product_service.dart';
import '../../services/purchase_service.dart';
import '../../services/sale_service.dart';
import '../../services/report_export_service.dart';
import '../../utils/branch_filter.dart';

const _kNavy = Color(0xFF0B2A5B);
const _kNavyLight = Color(0xFF14336B);
const _kApplyBlue = Color(0xFF2F6FED);

/// One row in the report, regardless of whether it came from a sale or a
/// purchase — lets both feed the same table/filter/grouping logic.
class _InvoiceRow {
  final String id;
  final String invoiceNo;
  final DateTime? date;
  final String partyName; // customer for a sale, supplier for a purchase
  final String branchId;
  final String branchName;
  final double gross;
  final double discount;
  final double netBill;
  final double? profit; // null for purchases — cost has no "profit" side
  final String cashierName;
  final bool isSale;
  final Sale? sale;
  final Purchase? purchase;

  _InvoiceRow({
    required this.id,
    required this.invoiceNo,
    required this.date,
    required this.partyName,
    required this.branchId,
    required this.branchName,
    required this.gross,
    required this.discount,
    required this.netBill,
    required this.profit,
    required this.cashierName,
    required this.isSale,
    this.sale,
    this.purchase,
  });
}

class InvoicesReportScreen extends StatefulWidget {
  const InvoicesReportScreen({super.key});

  @override
  State<InvoicesReportScreen> createState() => _InvoicesReportScreenState();
}

class _InvoicesReportScreenState extends State<InvoicesReportScreen> {
  final SaleService _saleService = SaleService();
  final PurchaseService _purchaseService = PurchaseService();
  final BranchService _branchService = BranchService();
  final ProductService _productService = ProductService();

  final _customerController = TextEditingController();
  final _invoiceNoController = TextEditingController();
  final _cashierController = TextEditingController();

  String _invoiceType = 'sales'; // 'sales' | 'purchases' | 'all'
  DateTime _fromDate =
  DateTime.now().subtract(const Duration(days: 21));
  DateTime _toDate = DateTime.now();

  // What's actually applied to the list — separate from the fields
  // above so typing doesn't refilter until "Apply Filters" is pressed,
  // matching the reference.
  String _appliedCustomer = '';
  String _appliedInvoiceNo = '';
  String _appliedCashier = '';

  final Set<String> _collapsedBranches = {};

  @override
  void dispose() {
    _customerController.dispose();
    _invoiceNoController.dispose();
    _cashierController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _appliedCustomer = _customerController.text.trim().toLowerCase();
      _appliedInvoiceNo = _invoiceNoController.text.trim().toLowerCase();
      _appliedCashier = _cashierController.text.trim().toLowerCase();
    });
  }

  // Groups rows by branch the same way build() does, so the PDF and
  // Excel output are organized identically to what's on screen.
  Map<String, List<_InvoiceRow>> _groupByBranch(List<_InvoiceRow> rows) {
    final grouped = <String, List<_InvoiceRow>>{};
    for (final row in rows) {
      final key = row.branchName.isEmpty ? 'Unassigned' : row.branchName;
      grouped.putIfAbsent(key, () => []).add(row);
    }
    return grouped;
  }

  // Turns the currently-filtered rows into the plain-string structure
  // ReportExportService needs, grouped and totalled exactly like the
  // on-screen report (same branch order, same Branch Total / Overall
  // Total figures).
  ReportData _buildReportData(List<_InvoiceRow> rows) {
    final grouped = _groupByBranch(rows);
    final branchNames = grouped.keys.toList()..sort();

    String money(double v) => v.toStringAsFixed(2);

    List<String> totals(String label, List<_InvoiceRow> list) => [
      '',
      '',
      '',
      label,
      money(list.fold<double>(0, (s, r) => s + r.gross)),
      money(list.fold<double>(0, (s, r) => s + r.discount)),
      money(list.fold<double>(0, (s, r) => s + r.netBill)),
      money(list.fold<double>(0, (s, r) => s + (r.profit ?? 0))),
      '',
    ];

    final sections = <ReportSection>[
      for (final branchName in branchNames)
        ReportSection(
          title: '$branchName (${grouped[branchName]!.length} invoices)',
          rows: [
            for (var i = 0; i < grouped[branchName]!.length; i++)
              [
                '${i + 1}',
                grouped[branchName]![i].invoiceNo,
                '${_formatDate(grouped[branchName]![i].date)} '
                    '${_formatTime(grouped[branchName]![i].date)}'
                    .trim(),
                grouped[branchName]![i].partyName,
                money(grouped[branchName]![i].gross),
                money(grouped[branchName]![i].discount),
                money(grouped[branchName]![i].netBill),
                grouped[branchName]![i].profit == null
                    ? '-'
                    : money(grouped[branchName]![i].profit!),
                grouped[branchName]![i].cashierName.isEmpty
                    ? '-'
                    : grouped[branchName]![i].cashierName,
              ],
          ],
          totalRow: totals(
              'Branch Total (${grouped[branchName]!.length} invoices)',
              grouped[branchName]!),
        ),
    ];

    return ReportData(
      title: 'Invoices Report',
      subtitle: 'Date range: ${_formatDateIso(_fromDate)} to '
          '${_formatDateIso(_toDate)} - ${rows.length} invoices',
      columns: const [
        'SR#',
        'Invoice No',
        'Date',
        'Customer',
        'Gross',
        'Discount',
        'Net Bill',
        'Profit',
        'Cashier',
      ],
      columnFlex: const [1, 1.6, 2.4, 3, 2, 1.8, 2, 2, 2.2],
      numericColumns: const {4, 5, 6, 7},
      sections: sections,
      overallRow: totals('OVERALL TOTAL (${rows.length} invoices)', rows),
    );
  }

  String get _exportFileName =>
      'invoices_report_${_formatDateIso(_fromDate)}_to_${_formatDateIso(_toDate)}';

  Future<void> _handleExcelExport(List<_InvoiceRow> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoices to export.')),
      );
      return;
    }
    try {
      await ReportExportService.exportExcel(
          _buildReportData(rows), _exportFileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel file saved: $_exportFileName.xlsx')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export Excel: $e')),
      );
    }
  }

  Future<void> _handlePrint(List<_InvoiceRow> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No invoices to print.')),
      );
      return;
    }
    try {
      await ReportExportService.printReport(
        _buildReportData(rows),
        fileName: _exportFileName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open print preview: $e')),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      setSelectedBranch(null, null);
      _invoiceType = 'sales';
      _fromDate = DateTime.now().subtract(const Duration(days: 21));
      _toDate = DateTime.now();
      _customerController.clear();
      _invoiceNoController.clear();
      _cashierController.clear();
      _appliedCustomer = '';
      _appliedInvoiceNo = '';
      _appliedCashier = '';
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => isFrom ? _fromDate = picked : _toDate = picked);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.year}';
  }

  String _formatDateIso(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the branch is changed from the top bar (or from the
    // dropdown below, which writes to the same notifier).
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, _, __) => _buildReport(context),
    );
  }

  Widget _buildReport(BuildContext context) {
    return StreamBuilder<List<Branch>>(
      stream: _branchService.streamBranches(),
      builder: (context, branchSnapshot) {
        final branches = branchSnapshot.data ?? [];

        return StreamBuilder<List<Product>>(
          stream: _productService.streamProducts(),
          builder: (context, productSnapshot) {
            final costByProductId = <String, double>{
              for (final p in productSnapshot.data ?? <Product>[])
                p.id: p.purchasePrice,
            };

            return StreamBuilder<List<Sale>>(
              stream: _saleService.streamSales(),
              builder: (context, saleSnapshot) {
                return StreamBuilder<List<Purchase>>(
                  stream: _purchaseService.streamPurchases(),
                  builder: (context, purchaseSnapshot) {
                    final rows = _buildRows(
                      sales: saleSnapshot.data ?? [],
                      purchases: purchaseSnapshot.data ?? [],
                      costByProductId: costByProductId,
                    );

                    final grouped = <String, List<_InvoiceRow>>{};
                    for (final row in rows) {
                      final key =
                      row.branchName.isEmpty ? 'Unassigned' : row.branchName;
                      grouped.putIfAbsent(key, () => []).add(row);
                    }
                    final branchNames = grouped.keys.toList()..sort();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderAndFilters(branches, rows),
                        const SizedBox(height: 20),
                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                'No invoices match these filters.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else ...[
                          for (final branchName in branchNames) ...[
                            _buildBranchGroup(
                                branchName, grouped[branchName]!, branches),
                            const SizedBox(height: 16),
                          ],
                          _buildOverallTotal(rows),
                          const SizedBox(height: 12),
                          _buildFooter(rows.length),
                        ],
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  List<_InvoiceRow> _buildRows({
    required List<Sale> sales,
    required List<Purchase> purchases,
    required Map<String, double> costByProductId,
  }) {
    final rows = <_InvoiceRow>[];

    if (_invoiceType == 'sales' || _invoiceType == 'all') {
      for (final sale in sales) {
        final date = sale.createdAt?.toDate();
        double profit = 0;
        for (final item in sale.items) {
          final cost = costByProductId[item.productId] ?? 0;
          profit += (item.unitPrice - cost) * item.quantity;
        }
        rows.add(_InvoiceRow(
          id: sale.id,
          invoiceNo: '${sale.invoiceNumber}',
          date: date,
          partyName: sale.customerName,
          branchId: sale.branchId,
          branchName: sale.branchName,
          gross: sale.totalAmount,
          discount: sale.discount,
          netBill: sale.netAmount,
          profit: profit,
          cashierName: sale.cashierName,
          isSale: true,
          sale: sale,
        ));
      }
    }

    if (_invoiceType == 'purchases' || _invoiceType == 'all') {
      for (final purchase in purchases) {
        final date = purchase.createdAt?.toDate();
        rows.add(_InvoiceRow(
          id: purchase.id,
          invoiceNo: purchase.id.length >= 6
              ? purchase.id.substring(0, 6)
              : purchase.id,
          date: date,
          partyName: purchase.supplierName,
          branchId: purchase.branchId,
          branchName: purchase.branchName,
          gross: purchase.totalAmount,
          discount: 0,
          netBill: purchase.totalAmount,
          profit: null,
          cashierName: '',
          isSale: false,
          purchase: purchase,
        ));
      }
    }

    return rows.where((row) {
      // The branch selector in the top bar and the Branch dropdown on this
      // page are the same app-wide setting (selectedBranchId), so picking a
      // branch in either place shows only that branch's invoices. Rows are
      // matched by branch id; older rows saved before an id was recorded
      // fall back to matching on the branch name.
      final selectedId = selectedBranchId.value;
      if (selectedId != null) {
        final selectedName = selectedBranchName.value;
        final matches = row.branchId == selectedId ||
            (row.branchId.isEmpty &&
                selectedName != null &&
                row.branchName == selectedName);
        if (!matches) return false;
      }
      if (row.date != null) {
        final d = DateTime(row.date!.year, row.date!.month, row.date!.day);
        final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
        final to = DateTime(_toDate.year, _toDate.month, _toDate.day);
        if (d.isBefore(from) || d.isAfter(to)) return false;
      }
      if (_appliedCustomer.isNotEmpty &&
          !row.partyName.toLowerCase().contains(_appliedCustomer)) {
        return false;
      }
      if (_appliedInvoiceNo.isNotEmpty &&
          !row.invoiceNo.toLowerCase().contains(_appliedInvoiceNo)) {
        return false;
      }
      if (_appliedCashier.isNotEmpty &&
          !row.cashierName.toLowerCase().contains(_appliedCashier)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => (b.date ?? DateTime(2000))
          .compareTo(a.date ?? DateTime(2000)));
  }

  Widget _buildHeaderAndFilters(List<Branch> branches, List<_InvoiceRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: _kNavy,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long, color: _kNavy),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INVOICES REPORT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.business,
                              color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'All Branches Invoice Management',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person,
                                color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Administrator',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kNavy,
                      backgroundColor: Colors.white,
                      side: BorderSide.none,
                    ),
                    onPressed: _resetFilters,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _handlePrint(rows),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E8E4F),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _handleExcelExport(rows),
                    icon: const Icon(Icons.grid_on, size: 16),
                    label: const Text('Excel'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 900;
              final fields = [
                _filterField(
                  label: 'BRANCH',
                  child: DropdownButtonFormField<String?>(
                    value: branches.any((b) => b.id == selectedBranchId.value)
                        ? selectedBranchId.value
                        : null,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    decoration: _filterDecoration(),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Branches')),
                      ...branches.map((b) => DropdownMenuItem(
                          value: b.id, child: Text(b.name))),
                    ],
                    onChanged: (v) {
                      final name = v == null
                          ? null
                          : branches.firstWhere((b) => b.id == v).name;
                      setSelectedBranch(v, name);
                    },
                  ),
                ),
                _filterField(
                  label: 'INVOICE TYPE',
                  child: DropdownButtonFormField<String>(
                    value: _invoiceType,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    decoration: _filterDecoration(),
                    items: const [
                      DropdownMenuItem(
                          value: 'sales', child: Text('Sales Invoices')),
                      DropdownMenuItem(
                          value: 'purchases',
                          child: Text('Purchase Invoices')),
                      DropdownMenuItem(
                          value: 'all', child: Text('All Invoices')),
                    ],
                    onChanged: (v) =>
                        setState(() => _invoiceType = v ?? 'sales'),
                  ),
                ),
                _filterField(
                  label: 'FROM DATE',
                  child: InkWell(
                    onTap: () => _pickDate(isFrom: true),
                    child: InputDecorator(
                      decoration: _filterDecoration(),
                      child: Text(_formatDate(_fromDate)),
                    ),
                  ),
                ),
                _filterField(
                  label: 'TO DATE',
                  child: InkWell(
                    onTap: () => _pickDate(isFrom: false),
                    child: InputDecorator(
                      decoration: _filterDecoration(),
                      child: Text(_formatDate(_toDate)),
                    ),
                  ),
                ),
                _filterField(
                  label: 'CUSTOMER',
                  child: TextField(
                    controller: _customerController,
                    style: const TextStyle(fontSize: 13),
                    decoration:
                    _filterDecoration(hint: 'Customer name...'),
                  ),
                ),
                _filterField(
                  label: 'INVOICE NO',
                  child: TextField(
                    controller: _invoiceNoController,
                    style: const TextStyle(fontSize: 13),
                    decoration: _filterDecoration(hint: 'Invoice no...'),
                  ),
                ),
              ];

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final f in fields)
                    SizedBox(width: narrow ? double.infinity : 180, child: f),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 700;
              final cashierField = SizedBox(
                width: narrow ? double.infinity : 260,
                child: _filterField(
                  label: 'CASHIER',
                  child: TextField(
                    controller: _cashierController,
                    style: const TextStyle(fontSize: 13),
                    decoration: _filterDecoration(hint: 'Cashier...'),
                  ),
                ),
              );
              final applyButton = SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kApplyBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Apply Filters'),
                ),
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cashierField,
                    const SizedBox(height: 10),
                    applyButton,
                  ],
                );
              }
              return Row(
                children: [
                  cashierField,
                  const SizedBox(width: 14),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: applyButton,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _filterField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _filterDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _kApplyBlue, width: 1.5),
      ),
    );
  }

  Widget _buildBranchGroup(
      String branchName, List<_InvoiceRow> rows, List<Branch> branches) {
    final collapsed = _collapsedBranches.contains(branchName);
    final branch = branches.where((b) => b.name == branchName);
    final branchNumber = branch.isNotEmpty ? branch.first.branchNumber : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() {
              if (collapsed) {
                _collapsedBranches.remove(branchName);
              } else {
                _collapsedBranches.add(branchName);
              }
            }),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF1FB),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(10),
                  bottom:
                  collapsed ? const Radius.circular(10) : Radius.zero,
                ),
              ),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          collapsed
                              ? Icons.chevron_right
                              : Icons.expand_more,
                          size: 20),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _kNavy,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.apartment,
                            color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                  Text(branchName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (branchNumber.isNotEmpty)
                    Text('Branch ID: $branchNumber',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text('${rows.length} invoices',
                        style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 56,
                dataRowMaxHeight: 64,
                headingRowColor: MaterialStateProperty.all(_kNavyLight),
                columns: const [
                  DataColumn(
                      label: Text('SR#',
                          style: TextStyle(color: Colors.white))),
                  DataColumn(
                      label: Text('INVOICE NO',
                          style: TextStyle(color: Colors.white))),
                  DataColumn(
                      label:
                      Text('DATE', style: TextStyle(color: Colors.white))),
                  DataColumn(
                      label: Text('CUSTOMER',
                          style: TextStyle(color: Colors.white))),
                  DataColumn(
                      label: Text('GROSS',
                          style: TextStyle(color: Colors.white)),
                      numeric: true),
                  DataColumn(
                      label: Text('DISCOUNT',
                          style: TextStyle(color: Colors.white)),
                      numeric: true),
                  DataColumn(
                      label: Text('NET BILL',
                          style: TextStyle(color: Colors.white)),
                      numeric: true),
                  DataColumn(
                      label: Text('PROFIT',
                          style: TextStyle(color: Colors.white)),
                      numeric: true),
                  DataColumn(
                      label: Text('CASHIER',
                          style: TextStyle(color: Colors.white))),
                  DataColumn(
                      label: Text('ACTION',
                          style: TextStyle(color: Colors.white))),
                ],
                rows: [
                  ...List.generate(rows.length, (i) {
                    final row = rows[i];
                    return DataRow(cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF1FB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(row.invoiceNo,
                            style: const TextStyle(
                                color: _kNavy, fontWeight: FontWeight.bold)),
                      )),
                      DataCell(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_formatDate(row.date)),
                          Text(_formatTime(row.date),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                        ],
                      )),
                      DataCell(Text(row.partyName)),
                      DataCell(Text(row.gross.toStringAsFixed(2))),
                      DataCell(Text(row.discount.toStringAsFixed(2),
                          style: const TextStyle(color: Colors.redAccent))),
                      DataCell(Text(row.netBill.toStringAsFixed(2),
                          style:
                          const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(
                        row.profit == null
                            ? '-'
                            : row.profit!.toStringAsFixed(2),
                        style: TextStyle(
                          color: (row.profit ?? 0) >= 0
                              ? Colors.green.shade700
                              : Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      )),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                              row.cashierName.isEmpty ? '-' : row.cashierName),
                        ],
                      )),
                      DataCell(IconButton(
                        icon: const Icon(Icons.remove_red_eye_outlined),
                        style: IconButton.styleFrom(
                          backgroundColor: _kApplyBlue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showInvoiceDetail(row, branches),
                      )),
                    ]);
                  }),
                  _branchTotalRow(rows, branchName),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // The bold summary row at the bottom of each branch's table — kept as
  // a real DataRow (not a separate widget) so its cells line up exactly
  // under the same columns without any manual width guessing.
  DataRow _branchTotalRow(List<_InvoiceRow> rows, String branchName) {
    final gross = rows.fold<double>(0, (sum, r) => sum + r.gross);
    final discount = rows.fold<double>(0, (sum, r) => sum + r.discount);
    final netBill = rows.fold<double>(0, (sum, r) => sum + r.netBill);
    final profit =
    rows.fold<double>(0, (sum, r) => sum + (r.profit ?? 0));

    TextStyle boldStyle([Color? color]) =>
        TextStyle(fontWeight: FontWeight.bold, color: color);

    return DataRow(
      color: MaterialStateProperty.all(const Color(0xFFEDF1FB)),
      cells: [
        const DataCell(SizedBox()),
        const DataCell(SizedBox()),
        const DataCell(SizedBox()),
        DataCell(Row(
          children: [
            Text('Branch Total', style: boldStyle()),
            const SizedBox(width: 6),
            Text('(${rows.length} invoices)',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        )),
        DataCell(Text(gross.toStringAsFixed(2), style: boldStyle())),
        DataCell(Text(discount.toStringAsFixed(2),
            style: boldStyle(Colors.redAccent))),
        DataCell(Text(netBill.toStringAsFixed(2), style: boldStyle())),
        DataCell(Text(profit.toStringAsFixed(2),
            style: boldStyle(Colors.green.shade700))),
        const DataCell(SizedBox()),
        const DataCell(SizedBox()),
      ],
    );
  }

  Widget _buildOverallTotal(List<_InvoiceRow> rows) {
    final gross = rows.fold<double>(0, (sum, r) => sum + r.gross);
    final discount = rows.fold<double>(0, (sum, r) => sum + r.discount);
    final netBill = rows.fold<double>(0, (sum, r) => sum + r.netBill);
    final profit =
    rows.fold<double>(0, (sum, r) => sum + (r.profit ?? 0));

    Widget cell(String label, String value, {Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label.isNotEmpty)
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          ],
        ),
      );
    }

    final label = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        const Text('OVERALL TOTAL',
            style: TextStyle(fontWeight: FontWeight.bold)),
        Text('(${rows.length} invoices)',
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD8F5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Five columns' worth of numbers plus a label don't fit on a
          // phone-width screen no matter how they're squeezed, so below
          // this width the label moves above a wrapping row of values
          // instead of everything overflowing sideways.
          if (constraints.maxWidth < 480) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    children: [
                      cell('Gross', gross.toStringAsFixed(2)),
                      cell('Discount', discount.toStringAsFixed(2),
                          color: Colors.redAccent),
                      cell('Net Bill', netBill.toStringAsFixed(2)),
                      cell('Profit', profit.toStringAsFixed(2),
                          color: Colors.green.shade700),
                    ],
                  ),
                ],
              ),
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: label,
                ),
              ),
              Expanded(child: cell('', gross.toStringAsFixed(2))),
              Expanded(
                  child: cell('', discount.toStringAsFixed(2),
                      color: Colors.redAccent)),
              Expanded(child: cell('', netBill.toStringAsFixed(2))),
              Expanded(
                  child: cell('', profit.toStringAsFixed(2),
                      color: Colors.green.shade700)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFooter(int invoiceCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 500;
        final left = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text('$invoiceCount invoices loaded',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        );
        final right = Text(
          'Date: ${_formatDateIso(_fromDate)} — ${_formatDateIso(_toDate)}',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [left, const SizedBox(height: 6), right],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [left, right],
        );
      },
    );
  }

  void _showInvoiceDetail(_InvoiceRow row, List<Branch> branches) {
    final matches = branches.where((b) => b.name == row.branchName);
    final branch = matches.isNotEmpty ? matches.first : null;

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFFF5F7FA),
        child: Column(
          children: [
            // Thin app-level control bar — not part of the printed
            // invoice itself, just Close/Print for the on-screen view.
            Container(
              width: double.infinity,
              color: Colors.white,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _printInvoice(row, branch),
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print'),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: _invoiceSlipContent(row, branch),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The visual layout replicated here matches the printed PDF built by
  // ReportExportService.printInvoiceSlip so what's on screen is what
  // gets printed.
  Widget _invoiceSlipContent(_InvoiceRow row, Branch? branch) {
    final items = row.isSale
        ? (row.sale?.items ?? []).map((i) => InvoiceLineItem(
      description: i.productName,
      qty: i.quantity.toStringAsFixed(2),
      unitPrice: i.unitPrice.toStringAsFixed(2),
      total: i.subtotal.toStringAsFixed(2),
    ))
        : (row.purchase?.items ?? []).map((i) => InvoiceLineItem(
      description: i.itemName,
      qty: i.quantity.toStringAsFixed(2),
      unitPrice: i.unitCost.toStringAsFixed(2),
      total: i.subtotal.toStringAsFixed(2),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFEDF1FB),
              backgroundImage: (branch?.logoUrl.isNotEmpty ?? false)
                  ? NetworkImage(branch!.logoUrl)
                  : null,
              child: (branch?.logoUrl.isEmpty ?? true)
                  ? const Icon(Icons.apartment, color: _kNavy)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (branch?.name ?? row.branchName).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _kNavy),
                  ),
                  if ((branch?.address ?? '').isNotEmpty)
                    Text(branch!.address,
                        style: const TextStyle(fontSize: 12)),
                  if ((branch?.contact ?? '').isNotEmpty)
                    Text('Contact: ${branch!.contact}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 2, color: _kNavy),
        const SizedBox(height: 18),
        Text(row.isSale ? 'BILL TO:' : 'SUPPLIER:',
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(row.partyName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(
            '${row.isSale ? "Sale" : "Purchase"} Invoice #: ${row.invoiceNo}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('Date: ${_formatDate(row.date)} ${_formatTime(row.date)}'),
        const SizedBox(height: 18),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
          columnWidths: const {
            0: FlexColumnWidth(0.6),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1.4),
            4: FlexColumnWidth(1.4),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: _kNavy),
              children: const [
                _SlipCell('SR#', bold: true, color: Colors.white),
                _SlipCell('PRODUCT DESCRIPTION',
                    bold: true, color: Colors.white),
                _SlipCell('QTY',
                    bold: true, color: Colors.white, right: true),
                _SlipCell('UNIT PRICE',
                    bold: true, color: Colors.white, right: true),
                _SlipCell('TOTAL',
                    bold: true, color: Colors.white, right: true),
              ],
            ),
            for (final entry in items.toList().asMap().entries)
              TableRow(children: [
                _SlipCell('${entry.key + 1}'),
                _SlipCell(entry.value.description),
                _SlipCell(entry.value.qty, right: true),
                _SlipCell(entry.value.unitPrice, right: true),
                _SlipCell(entry.value.total, right: true),
              ]),
          ],
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _totalLine('Gross', row.gross),
                _totalLine('Discount', row.discount),
                const Divider(),
                _totalLine('Net Bill', row.netBill, bold: true),
                if (row.profit != null) _totalLine('Profit', row.profit!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalLine(String label, double value, {bool bold = false}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value.toStringAsFixed(2), style: style),
        ],
      ),
    );
  }

  Future<void> _printInvoice(_InvoiceRow row, Branch? branch) async {
    Uint8List? logoBytes;
    if (branch != null && branch.logoUrl.isNotEmpty) {
      try {
        final response = await http
            .get(Uri.parse(branch.logoUrl))
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) logoBytes = response.bodyBytes;
      } catch (_) {
        // Printing without the logo is better than not printing at all.
      }
    }

    final items = row.isSale
        ? (row.sale?.items ?? []).map((i) => InvoiceLineItem(
      description: i.productName,
      qty: i.quantity.toStringAsFixed(2),
      unitPrice: i.unitPrice.toStringAsFixed(2),
      total: i.subtotal.toStringAsFixed(2),
    ))
        : (row.purchase?.items ?? []).map((i) => InvoiceLineItem(
      description: i.itemName,
      qty: i.quantity.toStringAsFixed(2),
      unitPrice: i.unitCost.toStringAsFixed(2),
      total: i.subtotal.toStringAsFixed(2),
    ));

    try {
      await ReportExportService.printInvoiceSlip(InvoiceData(
        branchName: branch?.name ?? row.branchName,
        branchAddress: branch?.address ?? '',
        branchContact: branch?.contact ?? '',
        branchLogoBytes: logoBytes,
        invoiceTypeLabel: row.isSale ? 'Sale Invoice' : 'Purchase Invoice',
        invoiceNo: row.invoiceNo,
        date: '${_formatDate(row.date)} ${_formatTime(row.date)}',
        partyLabel: row.isSale ? 'Bill To' : 'Supplier',
        partyName: row.partyName,
        items: items.toList(),
        gross: row.gross,
        discount: row.discount,
        netBill: row.netBill,
        profit: row.profit,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open print preview: $e')),
      );
    }
  }
}

class _SlipCell extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;
  final bool right;

  const _SlipCell(this.text,
      {this.bold = false, this.color, this.right = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
    );
  }
}