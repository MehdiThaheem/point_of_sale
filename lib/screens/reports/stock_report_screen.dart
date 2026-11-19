import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/brand.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/brand_service.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../services/report_export_service.dart';
import '../../services/user_service.dart';
import '../../utils/branch_filter.dart';

const _kNavyLight = Color(0xFF14336B);
const _kApplyBlue = Color(0xFF2F6FED);
const _kLowStockBg = Color(0xFFFBE1E1);

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();
  final BrandService _brandService = BrandService();
  final UserService _userService = UserService();

  final _searchController = TextEditingController();
  String _appliedSearch = '';
  String? _categoryFilter; // category id, null = All
  String? _brandFilter; // brand id, null = All
  String _stockFilter = 'All'; // All | In Stock | Low Stock | Out of Stock

  String _adminName = '';

  @override
  void initState() {
    super.initState();
    _loadAdminName();
  }

  Future<void> _loadAdminName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await _userService.getUserProfile(user.uid);
      final name = doc.data()?['name'] as String?;
      if (mounted && name != null && name.isNotEmpty) {
        setState(() => _adminName = name);
      }
    } catch (_) {
      // Header still works fine without a name — just omitted below.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  List<Product> _applyFilters(List<Product> products) {
    return products.where((p) {
      if (_categoryFilter != null && p.categoryId != _categoryFilter) {
        return false;
      }
      if (_brandFilter != null && p.brandId != _brandFilter) {
        return false;
      }
      switch (_stockFilter) {
        case 'In Stock':
          if (p.currentStock <= p.minStock) return false;
          break;
        case 'Low Stock':
          if (!(p.currentStock > 0 && p.isLowStock)) return false;
          break;
        case 'Out of Stock':
          if (p.currentStock > 0) return false;
          break;
      }
      if (_appliedSearch.isNotEmpty &&
          !p.name.toLowerCase().contains(_appliedSearch) &&
          !p.barcode.toLowerCase().contains(_appliedSearch)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchId, _) {
        return StreamBuilder<List<Category>>(
          stream: _categoryService.streamCategories(),
          builder: (context, categorySnapshot) {
            final categories = categorySnapshot.data ?? [];

            return StreamBuilder<List<Brand>>(
              stream: _brandService.streamBrands(),
              builder: (context, brandSnapshot) {
                final brands = brandSnapshot.data ?? [];

                return StreamBuilder<List<Product>>(
                  stream: _productService.streamProducts(),
                  builder: (context, productSnapshot) {
                    var allProducts = productSnapshot.data ?? [];
                    if (branchId != null) {
                      allProducts = allProducts
                          .where((p) => p.branchId == branchId)
                          .toList();
                    }
                    final products = _applyFilters(allProducts);

                    final lowStockCount = allProducts
                        .where((p) => p.currentStock > 0 && p.isLowStock)
                        .length;
                    final totalCostValue = allProducts.fold<double>(
                        0, (s, p) => s + p.currentStock * p.purchasePrice);
                    final totalSaleValue = allProducts.fold<double>(
                        0, (s, p) => s + p.currentStock * p.salePrice);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock Report',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (_adminName.isNotEmpty) 'User: $_adminName',
                            'Branch: ${selectedBranchName.value ?? 'All Branches'}',
                            _formatTimestamp(DateTime.now()),
                          ].join(' | '),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        _buildFilters(categories, brands),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _handlePrint(
                                  products, lowStockCount, totalCostValue, totalSaleValue),
                              icon: const Icon(Icons.print_outlined, size: 16),
                              label: const Text('Print'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E8E4F),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _handleExcelExport(
                                  products, lowStockCount, totalCostValue, totalSaleValue),
                              icon: const Icon(Icons.grid_on, size: 16),
                              label: const Text('Excel'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryBoxes(allProducts.length, lowStockCount,
                            totalCostValue, totalSaleValue),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(
                                  () => _appliedSearch = v.trim().toLowerCase()),
                          decoration: InputDecoration(
                            hintText: 'Search Product...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                              BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (products.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                allProducts.isEmpty
                                    ? 'No products yet.'
                                    : 'No products match these filters.',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          _buildTable(products),
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

  Widget _buildFilters(List<Category> categories, List<Brand> brands) {
    InputDecoration decoration() => InputDecoration(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );

    final categoryDropdown = DropdownButtonFormField<String?>(
      value: _categoryFilter,
      isExpanded: true,
      decoration: decoration(),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Categories')),
        ...categories.map(
                (c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
      ],
      onChanged: (v) => setState(() => _categoryFilter = v),
    );

    final brandDropdown = DropdownButtonFormField<String?>(
      value: _brandFilter,
      isExpanded: true,
      decoration: decoration(),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Brands')),
        ...brands.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
      ],
      onChanged: (v) => setState(() => _brandFilter = v),
    );

    final stockDropdown = DropdownButtonFormField<String>(
      value: _stockFilter,
      isExpanded: true,
      decoration: decoration(),
      items: const [
        DropdownMenuItem(value: 'All', child: Text('All Stock')),
        DropdownMenuItem(value: 'In Stock', child: Text('In Stock')),
        DropdownMenuItem(value: 'Low Stock', child: Text('Low Stock')),
        DropdownMenuItem(value: 'Out of Stock', child: Text('Out of Stock')),
      ],
      onChanged: (v) => setState(() => _stockFilter = v ?? 'All'),
    );

    final filterButton = SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _kApplyBlue,
          foregroundColor: Colors.white,
        ),
        onPressed: () => setState(() {}),
        child: const Text('Filter'),
      ),
    );

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 900;
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            categoryDropdown,
            const SizedBox(height: 10),
            brandDropdown,
            const SizedBox(height: 10),
            stockDropdown,
            const SizedBox(height: 10),
            filterButton,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: categoryDropdown),
          const SizedBox(width: 12),
          Expanded(child: brandDropdown),
          const SizedBox(width: 12),
          Expanded(child: stockDropdown),
          const SizedBox(width: 12),
          filterButton,
        ],
      );
    });
  }

  Widget _buildSummaryBoxes(int totalProducts, int lowStockCount,
      double totalCostValue, double totalSaleValue) {
    Widget box(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final boxes = [
      box('Total Products', '$totalProducts'),
      box('Low Stock Items', '$lowStockCount'),
      box('Total Cost Value', totalCostValue.toStringAsFixed(2)),
      box('Total Sale Value', totalSaleValue.toStringAsFixed(2)),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 760;
      if (narrow) {
        return Column(
          children: [
            for (var i = 0; i < boxes.length; i += 2) ...[
              Row(
                children: [
                  boxes[i],
                  const SizedBox(width: 12),
                  if (i + 1 < boxes.length) boxes[i + 1],
                ],
              ),
              if (i + 2 < boxes.length) const SizedBox(height: 12),
            ],
          ],
        );
      }
      return Row(
        children: [
          for (var i = 0; i < boxes.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            boxes[i],
          ],
        ],
      );
    });
  }

  Widget _buildTable(List<Product> products) {
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
            DataColumn(label: Text('#', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('Name', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('Barcode', style: TextStyle(color: Colors.white))),
            DataColumn(
                label: Text('Stock', style: TextStyle(color: Colors.white)),
                numeric: true),
            DataColumn(
                label: Text('Cost', style: TextStyle(color: Colors.white)),
                numeric: true),
            DataColumn(
                label: Text('Price', style: TextStyle(color: Colors.white)),
                numeric: true),
            DataColumn(
                label:
                Text('Cost Value', style: TextStyle(color: Colors.white)),
                numeric: true),
            DataColumn(
                label:
                Text('Sale Value', style: TextStyle(color: Colors.white)),
                numeric: true),
            DataColumn(label: Text('Category', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('Brand', style: TextStyle(color: Colors.white))),
            DataColumn(label: Text('Alert', style: TextStyle(color: Colors.white))),
          ],
          rows: List.generate(products.length, (i) {
            final p = products[i];
            final lowStock = p.isLowStock;
            return DataRow(
              color: lowStock
                  ? MaterialStateProperty.all(_kLowStockBg)
                  : null,
              cells: [
                DataCell(Text('${i + 1}')),
                DataCell(Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(p.barcode.isEmpty ? '-' : p.barcode)),
                DataCell(Text(
                  p.currentStock.toStringAsFixed(3),
                  style: TextStyle(
                    color: lowStock ? Colors.red : Colors.black87,
                    fontWeight:
                    lowStock ? FontWeight.bold : FontWeight.normal,
                  ),
                )),
                DataCell(Text(p.purchasePrice.toStringAsFixed(2))),
                DataCell(Text(p.salePrice.toStringAsFixed(2))),
                DataCell(Text(
                    (p.currentStock * p.purchasePrice).toStringAsFixed(2))),
                DataCell(
                    Text((p.currentStock * p.salePrice).toStringAsFixed(2))),
                DataCell(
                    Text(p.categoryName.isEmpty ? '-' : p.categoryName)),
                DataCell(Text(p.brandName.isEmpty ? '-' : p.brandName)),
                DataCell(Text(p.minStock.toStringAsFixed(0))),
              ],
            );
          }),
        ),
      ),
    );
  }

  ReportData _buildReportData(List<Product> products, int lowStockCount,
      double totalCostValue, double totalSaleValue) {
    return ReportData(
      title: 'Stock Report',
      subtitle: 'Branch: ${selectedBranchName.value ?? 'All Branches'} - '
          '${_formatTimestamp(DateTime.now())}',
      columns: const [
        '#',
        'Name',
        'Barcode',
        'Stock',
        'Cost',
        'Price',
        'Cost Value',
        'Sale Value',
        'Category',
        'Brand',
        'Alert',
      ],
      columnFlex: const [0.6, 2.4, 1.4, 1, 1.2, 1.2, 1.4, 1.4, 1.6, 1.4, 0.8],
      numericColumns: const {3, 4, 5, 6, 7, 10},
      sections: [
        ReportSection(
          title: 'Products',
          rows: [
            for (var i = 0; i < products.length; i++)
              [
                '${i + 1}',
                products[i].name,
                products[i].barcode.isEmpty ? '-' : products[i].barcode,
                products[i].currentStock.toStringAsFixed(3),
                products[i].purchasePrice.toStringAsFixed(2),
                products[i].salePrice.toStringAsFixed(2),
                (products[i].currentStock * products[i].purchasePrice)
                    .toStringAsFixed(2),
                (products[i].currentStock * products[i].salePrice)
                    .toStringAsFixed(2),
                products[i].categoryName.isEmpty
                    ? '-'
                    : products[i].categoryName,
                products[i].brandName.isEmpty ? '-' : products[i].brandName,
                products[i].minStock.toStringAsFixed(0),
              ],
          ],
          totalRow: const ['', '', '', '', '', '', '', '', '', '', ''],
        ),
      ],
      overallRow: [
        'Total Products: ${products.length}',
        'Low Stock: $lowStockCount',
        'Total Cost Value: ${totalCostValue.toStringAsFixed(2)}',
        'Total Sale Value: ${totalSaleValue.toStringAsFixed(2)}',
      ],
    );
  }

  Future<void> _handlePrint(List<Product> products, int lowStockCount,
      double totalCostValue, double totalSaleValue) async {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products to print.')),
      );
      return;
    }
    try {
      await ReportExportService.printReport(
        _buildReportData(
            products, lowStockCount, totalCostValue, totalSaleValue),
        fileName: 'stock_report',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open print preview: $e')),
      );
    }
  }

  Future<void> _handleExcelExport(List<Product> products, int lowStockCount,
      double totalCostValue, double totalSaleValue) async {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products to export.')),
      );
      return;
    }
    try {
      await ReportExportService.exportExcel(
        _buildReportData(
            products, lowStockCount, totalCostValue, totalSaleValue),
        'stock_report',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel file saved: stock_report.xlsx')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export Excel: $e')),
      );
    }
  }
}