import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/purchase.dart';
import '../../models/raw_material.dart';
import '../../models/sales.dart';
import '../../services/product_service.dart';
import '../../services/purchase_service.dart';
import '../../services/raw_material_service.dart';
import '../../services/sale_service.dart';
import '../../services/report_export_service.dart';
import '../../utils/branch_filter.dart';

const _kNavy = Color(0xFF0B2A5B);
const _kNavyLight = Color(0xFF14336B);
const _kApplyBlue = Color(0xFF2F6FED);
const _kExcessBg = Color(0xFFFBF3D9);
const _kShortBg = Color(0xFFFBE1E1);

/// One reconciled row: recorded stock vs. (total purchased − total sold).
/// A mismatch usually means stock was edited by hand somewhere (Add
/// Product's Current Stock field, a Stock Adjustment not tied to a
/// purchase, etc) rather than through a tracked purchase/sale.
class _AuditRow {
  final String name;
  final String type; // 'Product' or 'Raw Material'
  final double purchased;
  final double sold;
  final double stock;
  final String unit;

  _AuditRow({
    required this.name,
    required this.type,
    required this.purchased,
    required this.sold,
    required this.stock,
    required this.unit,
  });

  double get remaining => purchased - sold;
  double get diff => stock - remaining;
  String get status =>
      diff > 0 ? 'EXCESS' : (diff < 0 ? 'SHORT' : 'OK');
  String get remarks {
    if (diff > 0) return 'Qty More by ${diff.toStringAsFixed(3)}';
    if (diff < 0) {
      return 'Qty Short by ${(-diff).toStringAsFixed(3)}';
    }
    return 'Matches purchase/sale records';
  }
}

class StockAuditScreen extends StatefulWidget {
  const StockAuditScreen({super.key});

  @override
  State<StockAuditScreen> createState() => _StockAuditScreenState();
}

class _StockAuditScreenState extends State<StockAuditScreen> {
  final ProductService _productService = ProductService();
  final RawMaterialService _rawMaterialService = RawMaterialService();
  final SaleService _saleService = SaleService();
  final PurchaseService _purchaseService = PurchaseService();

  final _searchController = TextEditingController();
  String _appliedSearch = '';
  String _statusFilter = 'All'; // All | OK | SHORT | EXCESS

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_AuditRow> _buildRows({
    required List<Product> products,
    required List<RawMaterial> rawMaterials,
    required List<Sale> sales,
    required List<Purchase> purchases,
  }) {
    final purchasedByItem = <String, double>{};
    for (final purchase in purchases) {
      for (final item in purchase.items) {
        purchasedByItem[item.itemId] =
            (purchasedByItem[item.itemId] ?? 0) + item.quantity;
      }
    }

    final soldByProduct = <String, double>{};
    for (final sale in sales) {
      for (final item in sale.items) {
        soldByProduct[item.productId] =
            (soldByProduct[item.productId] ?? 0) + item.quantity;
      }
    }

    final rows = <_AuditRow>[
      for (final p in products)
        _AuditRow(
          name: p.name,
          type: 'Product',
          purchased: purchasedByItem[p.id] ?? 0,
          sold: soldByProduct[p.id] ?? 0,
          stock: p.currentStock,
          unit: p.unit,
        ),
      // Raw materials aren't tied to a branch and aren't sold directly
      // to customers (they're consumed internally), so "Sale" is
      // always 0 for them here — this still catches stock that was
      // hand-edited without a matching purchase record.
      for (final r in rawMaterials)
        _AuditRow(
          name: r.name,
          type: 'Raw Material',
          purchased: purchasedByItem[r.id] ?? 0,
          sold: 0,
          stock: r.currentStock,
          unit: r.unit,
        ),
    ];

    return rows.where((row) {
      if (_statusFilter != 'All' && row.status != _statusFilter) {
        return false;
      }
      if (_appliedSearch.isNotEmpty &&
          !row.name.toLowerCase().contains(_appliedSearch)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever the branch is changed from the top bar.
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchId, _) {
        return StreamBuilder<List<Product>>(
          stream: _productService.streamProducts(),
          builder: (context, productSnapshot) {
            var products = productSnapshot.data ?? [];
            // Raw materials have no branch of their own, so only
            // Products are narrowed down when a branch is selected.
            if (branchId != null) {
              products = products.where((p) => p.branchId == branchId).toList();
            }

            return StreamBuilder<List<RawMaterial>>(
              stream: _rawMaterialService.streamRawMaterials(),
              builder: (context, rawSnapshot) {
                final rawMaterials = rawSnapshot.data ?? [];

                return StreamBuilder<List<Sale>>(
                  stream: _saleService.streamSales(),
                  builder: (context, saleSnapshot) {
                    final sales = saleSnapshot.data ?? [];

                    return StreamBuilder<List<Purchase>>(
                      stream: _purchaseService.streamPurchases(),
                      builder: (context, purchaseSnapshot) {
                        final purchases = purchaseSnapshot.data ?? [];

                        final rows = _buildRows(
                          products: products,
                          rawMaterials: rawMaterials,
                          sales: sales,
                          purchases: purchases,
                        );

                        final okCount =
                            rows.where((r) => r.status == 'OK').length;
                        final shortCount =
                            rows.where((r) => r.status == 'SHORT').length;
                        final excessCount =
                            rows.where((r) => r.status == 'EXCESS').length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Audit Report',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _buildSummaryAndFilters(
                                okCount, shortCount, excessCount, rows),
                            const SizedBox(height: 16),
                            if (rows.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(
                                  child: Text(
                                    'No items match these filters.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              _buildTable(rows),
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
      },
    );
  }

  Widget _buildSummaryAndFilters(
      int okCount, int shortCount, int excessCount, List<_AuditRow> rows) {
    // Plain box: it must NOT be an Expanded, because on narrow screens it
    // is placed in a Column inside a scroll view (unbounded height), where
    // Expanded makes the whole screen fail to render.
    Widget statBox(String label, int count, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          '$label: $count',
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          final boxes = [
            statBox('OK', okCount, Colors.green.shade700),
            statBox('Short', shortCount, Colors.red),
            statBox('Excess', excessCount, const Color(0xFFB26A00)),
          ];
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final b in boxes) ...[b, const SizedBox(height: 10)]
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < boxes.length; i++) ...[
                if (i > 0) const SizedBox(width: 14),
                Expanded(child: boxes[i]),
              ],
            ],
          );
        }),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          final search = TextField(
            controller: _searchController,
            onSubmitted: (_) =>
                setState(() => _appliedSearch = _searchController.text
                    .trim()
                    .toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search Product...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          );
          final statusDropdown = DropdownButtonFormField<String>(
            value: _statusFilter,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All')),
              DropdownMenuItem(value: 'OK', child: Text('OK')),
              DropdownMenuItem(value: 'SHORT', child: Text('Short')),
              DropdownMenuItem(value: 'EXCESS', child: Text('Excess')),
            ],
            onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
          );
          final filterButton = SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kApplyBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () => setState(() => _appliedSearch =
                  _searchController.text.trim().toLowerCase()),
              child: const Text('Filter'),
            ),
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 10),
                statusDropdown,
                const SizedBox(height: 10),
                filterButton,
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 3, child: search),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: statusDropdown),
              const SizedBox(width: 12),
              filterButton,
            ],
          );
        }),
        const SizedBox(height: 14),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _handlePrint(rows),
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Print'),
            ),
            const SizedBox(width: 10),
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
    );
  }

  Widget _buildTable(List<_AuditRow> rows) {
    Color rowColor(_AuditRow row) {
      if (row.status == 'EXCESS') return _kExcessBg;
      if (row.status == 'SHORT') return _kShortBg;
      return Colors.white;
    }

    Color statusColor(String status) {
      switch (status) {
        case 'EXCESS':
          return const Color(0xFFB26A00);
        case 'SHORT':
          return Colors.red;
        default:
          return Colors.green.shade700;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMinHeight: 52,
          dataRowMaxHeight: 60,
          headingRowColor: MaterialStateProperty.all(_kNavyLight),
          columns: const [
            DataColumn(label: Text('ID', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('Name', style: TextStyle(color: Colors.white))),
            DataColumn(
                label: Text('Purchase', style: TextStyle(color: Colors.white)),
                numeric: true),
            DataColumn(
                label: Text('Sale', style: TextStyle(color: Colors.white)),
                numeric: true),
            DataColumn(
                label: Text('Remaining', style: TextStyle(color: Colors.white)),
                numeric: true),
            DataColumn(
                label: Text('Stock', style: TextStyle(color: Colors.white)),
                numeric: true),
            DataColumn(label: Text('Status', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('Remarks', style: TextStyle(color: Colors.white))),
          ],
          rows: List.generate(rows.length, (i) {
            final row = rows[i];
            return DataRow(
              color: MaterialStateProperty.all(rowColor(row)),
              cells: [
                DataCell(Text('${i + 1}')),
                DataCell(Text(row.name,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(row.purchased.toStringAsFixed(2))),
                DataCell(Text(row.sold.toStringAsFixed(2))),
                DataCell(Text(row.remaining.toStringAsFixed(2))),
                DataCell(Text(row.stock.toStringAsFixed(3))),
                DataCell(Text(row.status,
                    style: TextStyle(
                        color: statusColor(row.status),
                        fontWeight: FontWeight.bold))),
                DataCell(Text(row.remarks)),
              ],
            );
          }),
        ),
      ),
    );
  }

  ReportData _buildReportData(List<_AuditRow> rows) {
    return ReportData(
      title: 'Stock Audit Report',
      subtitle:
      '${rows.length} items - '
          '${rows.where((r) => r.status == "OK").length} OK, '
          '${rows.where((r) => r.status == "SHORT").length} Short, '
          '${rows.where((r) => r.status == "EXCESS").length} Excess',
      columns: const [
        'ID',
        'Name',
        'Purchase',
        'Sale',
        'Remaining',
        'Stock',
        'Status',
        'Remarks',
      ],
      columnFlex: const [0.8, 3, 1.4, 1.4, 1.4, 1.4, 1.4, 2.6],
      numericColumns: const {2, 3, 4, 5},
      sections: [
        ReportSection(
          title: 'Stock Audit',
          rows: [
            for (var i = 0; i < rows.length; i++)
              [
                '${i + 1}',
                rows[i].name,
                rows[i].purchased.toStringAsFixed(2),
                rows[i].sold.toStringAsFixed(2),
                rows[i].remaining.toStringAsFixed(2),
                rows[i].stock.toStringAsFixed(3),
                rows[i].status,
                rows[i].remarks,
              ],
          ],
          totalRow: const ['', '', '', '', '', '', '', ''],
        ),
      ],
      overallRow: [
        'Total items: ${rows.length}',
        'OK: ${rows.where((r) => r.status == "OK").length}',
        'Short: ${rows.where((r) => r.status == "SHORT").length}',
        'Excess: ${rows.where((r) => r.status == "EXCESS").length}',
      ],
    );
  }

  Future<void> _handlePrint(List<_AuditRow> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to print.')),
      );
      return;
    }
    try {
      await ReportExportService.printReport(_buildReportData(rows),
          fileName: 'stock_audit');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open print preview: $e')),
      );
    }
  }

  Future<void> _handleExcelExport(List<_AuditRow> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to export.')),
      );
      return;
    }
    try {
      await ReportExportService.exportExcel(
          _buildReportData(rows), 'stock_audit');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel file saved: stock_audit.xlsx')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export Excel: $e')),
      );
    }
  }
}