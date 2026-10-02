import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../services/purchase_service.dart';
import '../../models/raw_material.dart';
import '../../services/sale_service.dart';
import '../../services/product_service.dart';
import '../../services/raw_material_service.dart';
import '../../models/purchase.dart';
import '../../models/sales.dart';
import '../../utils/branch_filter.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SaleService _saleService = SaleService();
  final PurchaseService _purchaseService = PurchaseService();
  final ProductService _productService = ProductService();
  final RawMaterialService _rawMaterialService = RawMaterialService();

  @override
  Widget build(BuildContext context) {
    // Follows the branch chosen in the top bar (fixed for Managers).
    return ValueListenableBuilder<String?>(
      valueListenable: selectedBranchId,
      builder: (context, branchId, _) => _body(branchId),
    );
  }

  Widget _body(String? branchId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reports',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Business performance summary.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Sale>>(
          stream: _saleService.streamSales(),
          builder: (context, saleSnapshot) {
            final sales = (saleSnapshot.data ?? <Sale>[])
                .where((s) => branchId == null || s.branchId == branchId)
                .toList();

            return StreamBuilder<List<Purchase>>(
              stream: _purchaseService.streamPurchases(),
              builder: (context, purchaseSnapshot) {
                final purchases = (purchaseSnapshot.data ?? <Purchase>[])
                    .where((p) => branchId == null || p.branchId == branchId)
                    .toList();

                final totalSales = sales.fold<double>(
                    0, (sum, s) => sum + s.totalAmount);
                final totalPurchases = purchases.fold<double>(
                    0, (sum, p) => sum + p.totalAmount);
                final totalDueFromCustomers = sales.fold<double>(
                    0, (sum, s) => sum + s.dueAmount);
                final totalDueToSuppliers = purchases.fold<double>(
                    0, (sum, p) => sum + p.dueAmount);
                final estimatedProfit = totalSales - totalPurchases;

                return GridView(
                  gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.5,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _reportCard('Total Sales', totalSales, Colors.blue,
                        Icons.point_of_sale_outlined),
                    _reportCard('Total Purchases', totalPurchases,
                        Colors.green, Icons.shopping_bag_outlined),
                    _reportCard(
                        'Estimated Profit',
                        estimatedProfit,
                        estimatedProfit >= 0 ? Colors.teal : Colors.red,
                        Icons.trending_up),
                    _reportCard(
                        'Due from Customers',
                        totalDueFromCustomers,
                        Colors.orange,
                        Icons.person_add_alt_1_outlined),
                    _reportCard('Due to Suppliers', totalDueToSuppliers,
                        Colors.redAccent, Icons.person_remove_outlined),
                    _reportCard('Total Orders', sales.length.toDouble(),
                        Colors.purple, Icons.receipt_long_outlined,
                        isCount: true),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 24),
        const Text(
          'Low Stock Alerts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Product>>(
          stream: _productService.streamProducts(),
          builder: (context, productSnapshot) {
            final lowProducts =
            (productSnapshot.data ?? <Product>[])
                .where((p) =>
            (branchId == null || p.branchId == branchId) &&
                p.isLowStock)
                .toList();

            return StreamBuilder<List<RawMaterial>>(
              stream: _rawMaterialService.streamRawMaterials(),
              builder: (context, rawSnapshot) {
                final lowRaw = (rawSnapshot.data ?? <RawMaterial>[])
                    .where((r) =>
                (branchId == null || r.branchId == branchId) &&
                    r.isLowStock)
                    .toList();

                if (lowProducts.isEmpty && lowRaw.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Nothing is low on stock right now.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return Card(
                  child: Column(
                    children: [
                      ...lowProducts.map((p) => ListTile(
                        leading: const Icon(Icons.inventory_2_outlined,
                            color: Colors.red),
                        title: Text(p.name),
                        subtitle: const Text('Product'),
                        trailing: Text(
                          '${p.currentStock} ${p.unit}',
                          style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                      )),
                      ...lowRaw.map((r) => ListTile(
                        leading: const Icon(Icons.category_outlined,
                            color: Colors.red),
                        title: Text(r.name),
                        subtitle: const Text('Raw Material'),
                        trailing: Text(
                          '${r.currentStock} ${r.unit}',
                          style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                      )),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _reportCard(
      String title, double value, Color color, IconData icon,
      {bool isCount = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  isCount ? value.toInt().toString() : value.toStringAsFixed(0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}