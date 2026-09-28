import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/raw_material.dart';
import '../../services/product_service.dart';
import '../../services/raw_material_service.dart';

class StockAuditScreen extends StatefulWidget {
  const StockAuditScreen({super.key});

  @override
  State<StockAuditScreen> createState() => _StockAuditScreenState();
}

class _StockAuditScreenState extends State<StockAuditScreen> {
  final ProductService _productService = ProductService();
  final RawMaterialService _rawMaterialService = RawMaterialService();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stock Audit',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Items that are out of stock or below their minimum stock level.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Product>>(
          stream: _productService.streamProducts(),
          builder: (context, productSnapshot) {
            final products = productSnapshot.data ?? [];
            final outOfStockProducts =
            products.where((p) => p.currentStock <= 0).toList();
            final lowStockProducts = products
                .where((p) => p.currentStock > 0 && p.isLowStock)
                .toList();

            return StreamBuilder<List<RawMaterial>>(
              stream: _rawMaterialService.streamRawMaterials(),
              builder: (context, rawSnapshot) {
                final rawMaterials = rawSnapshot.data ?? [];
                final outOfStockRaw =
                rawMaterials.where((r) => r.currentStock <= 0).toList();
                final lowStockRaw = rawMaterials
                    .where((r) => r.currentStock > 0 && r.isLowStock)
                    .toList();

                final totalIssues = outOfStockProducts.length +
                    lowStockProducts.length +
                    outOfStockRaw.length +
                    lowStockRaw.length;

                if (totalIssues == 0) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Colors.green, size: 48),
                          SizedBox(height: 12),
                          Text('Everything looks good!',
                              style:
                              TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('No stock issues found.',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (outOfStockProducts.isNotEmpty ||
                        outOfStockRaw.isNotEmpty) ...[
                      _sectionHeader('Out of Stock', Colors.red),
                      ...outOfStockProducts.map(
                              (p) => _tile(p.name, 'Product', p.currentStock, p.unit)),
                      ...outOfStockRaw.map((r) =>
                          _tile(r.name, 'Raw Material', r.currentStock, r.unit)),
                      const SizedBox(height: 20),
                    ],
                    if (lowStockProducts.isNotEmpty ||
                        lowStockRaw.isNotEmpty) ...[
                      _sectionHeader('Low Stock', Colors.orange),
                      ...lowStockProducts.map(
                              (p) => _tile(p.name, 'Product', p.currentStock, p.unit)),
                      ...lowStockRaw.map((r) =>
                          _tile(r.name, 'Raw Material', r.currentStock, r.unit)),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _tile(String name, String type, double stock, String unit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          type == 'Product' ? Icons.inventory_2_outlined : Icons.category_outlined,
          color: stock <= 0 ? Colors.red : Colors.orange,
        ),
        title: Text(name),
        subtitle: Text(type),
        trailing: Text(
          '$stock $unit',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: stock <= 0 ? Colors.red : Colors.orange,
          ),
        ),
      ),
    );
  }
}