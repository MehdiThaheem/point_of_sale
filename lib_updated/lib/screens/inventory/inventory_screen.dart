import 'package:flutter/material.dart';
import '../../models/product.dart';
import '../../models/raw_material.dart';
import '../../services/product_service.dart';
import '../../services/raw_material_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
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

  void _adjustProductStock(Product product) {
    final controller = TextEditingController();
    String mode = 'add'; // add or reduce

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Adjust Stock — ${product.name}'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width < 420
                ? MediaQuery.of(context).size.width * 0.85
                : 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current Stock: ${product.currentStock} ${product.unit}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Add Stock'),
                        selected: mode == 'add',
                        onSelected: (_) =>
                            setDialogState(() => mode = 'add'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Reduce Stock'),
                        selected: mode == 'reduce',
                        onSelected: (_) =>
                            setDialogState(() => mode = 'reduce'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(controller.text.trim()) ?? 0;
                if (qty <= 0) return;

                final delta = mode == 'add' ? qty : -qty;
                await _productService.adjustStock(product.id, delta);

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _adjustRawMaterialStock(RawMaterial item) {
    final controller = TextEditingController();
    String mode = 'add';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Adjust Stock — ${item.name}'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width < 420
                ? MediaQuery.of(context).size.width * 0.85
                : 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Current Stock: ${item.currentStock} ${item.unit}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Add Stock'),
                        selected: mode == 'add',
                        onSelected: (_) =>
                            setDialogState(() => mode = 'add'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Reduce Stock'),
                        selected: mode == 'reduce',
                        onSelected: (_) =>
                            setDialogState(() => mode = 'reduce'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(controller.text.trim()) ?? 0;
                if (qty <= 0) return;

                final delta = mode == 'add' ? qty : -qty;
                await _rawMaterialService.adjustStock(item.id, delta);

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inventory',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'View stock levels and make quick adjustments.',
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
          height: 560,
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
            child: Text(
              'No products yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: product.isLowStock
                      ? Colors.red.withOpacity(0.15)
                      : Colors.green.withOpacity(0.15),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: product.isLowStock ? Colors.red : Colors.green,
                  ),
                ),
                title: Text(product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Stock: ${product.currentStock} ${product.unit}'
                      '${product.isLowStock ? '  •  LOW STOCK' : ''}',
                  style: TextStyle(
                    color: product.isLowStock ? Colors.red : Colors.grey,
                  ),
                ),
                trailing: OutlinedButton.icon(
                  onPressed: () => _adjustProductStock(product),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Adjust'),
                ),
              ),
            );
          },
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
            child: Text(
              'No raw materials yet.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: item.isLowStock
                      ? Colors.red.withOpacity(0.15)
                      : Colors.blue.withOpacity(0.15),
                  child: Icon(
                    Icons.category_outlined,
                    color: item.isLowStock ? Colors.red : Colors.blue,
                  ),
                ),
                title: Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Stock: ${item.currentStock} ${item.unit}'
                      '${item.isLowStock ? '  •  LOW STOCK' : ''}',
                  style: TextStyle(
                    color: item.isLowStock ? Colors.red : Colors.grey,
                  ),
                ),
                trailing: OutlinedButton.icon(
                  onPressed: () => _adjustRawMaterialStock(item),
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Adjust'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}