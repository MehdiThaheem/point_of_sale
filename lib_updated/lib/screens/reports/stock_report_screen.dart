import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/raw_material.dart';
import '../../services/product_service.dart';
import '../../services/raw_material_service.dart';

class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductService _productService = ProductService();
  final RawMaterialService _rawMaterialService = RawMaterialService();

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stock Report',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Current stock levels and stock value for everything you hold.',
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
              Tab(text: 'Products'),
              Tab(text: 'Raw Materials'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProductsTab(),
              _buildRawMaterialsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTab() {
    return StreamBuilder<List<Product>>(
      stream: _productService.streamProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data ?? [];

        if (products.isEmpty) {
          return const Center(
            child: Text('No products yet.', style: TextStyle(color: Colors.grey)),
          );
        }

        final totalValue = products.fold<double>(
            0, (sum, p) => sum + (p.currentStock * p.purchasePrice));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryBar('Total Stock Value: ${totalValue.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final p = products[index];
                  final value = p.currentStock * p.purchasePrice;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                          'Stock: ${p.currentStock} ${p.unit}  •  Unit Cost: ${p.purchasePrice.toStringAsFixed(0)}'),
                      trailing: Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
  }

  Widget _buildRawMaterialsTab() {
    return StreamBuilder<List<RawMaterial>>(
      stream: _rawMaterialService.streamRawMaterials(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const Center(
            child: Text('No raw materials yet.',
                style: TextStyle(color: Colors.grey)),
          );
        }

        final totalValue = items.fold<double>(
            0, (sum, r) => sum + (r.currentStock * r.costPerUnit));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryBar('Total Stock Value: ${totalValue.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final r = items[index];
                  final value = r.currentStock * r.costPerUnit;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(r.name),
                      subtitle: Text(
                          'Stock: ${r.currentStock} ${r.unit}  •  Unit Cost: ${r.costPerUnit.toStringAsFixed(0)}'),
                      trailing: Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
  }

  Widget _summaryBar(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}