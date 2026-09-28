import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/product.dart';
import '../../models/raw_material.dart';
import '../../models/supplier.dart';
import '../../services/customer_service.dart';
import '../../services/product_service.dart';
import '../../services/raw_material_service.dart';
import '../../services/supplier_service.dart';

class BalanceSheetScreen extends StatefulWidget {
  const BalanceSheetScreen({super.key});

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  final ProductService _productService = ProductService();
  final RawMaterialService _rawMaterialService = RawMaterialService();
  final CustomerService _customerService = CustomerService();
  final SupplierService _supplierService = SupplierService();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Balance Sheet',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'A snapshot of what the business owns vs. what it owes.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Product>>(
          stream: _productService.streamProducts(),
          builder: (context, productSnapshot) {
            final products = productSnapshot.data ?? [];
            final productStockValue = products.fold<double>(
                0, (sum, p) => sum + (p.currentStock * p.purchasePrice));

            return StreamBuilder<List<RawMaterial>>(
              stream: _rawMaterialService.streamRawMaterials(),
              builder: (context, rawSnapshot) {
                final rawMaterials = rawSnapshot.data ?? [];
                final rawStockValue = rawMaterials.fold<double>(
                    0, (sum, r) => sum + (r.currentStock * r.costPerUnit));

                return StreamBuilder<List<Customer>>(
                  stream: _customerService.streamCustomers(),
                  builder: (context, customerSnapshot) {
                    final customers = customerSnapshot.data ?? [];
                    final totalReceivable = customers.fold<double>(
                        0, (sum, c) => sum + c.totalReceivable);

                    return StreamBuilder<List<Supplier>>(
                      stream: _supplierService.streamSuppliers(),
                      builder: (context, supplierSnapshot) {
                        final suppliers = supplierSnapshot.data ?? [];
                        final totalPayable = suppliers.fold<double>(
                            0, (sum, s) => sum + s.totalPayable);

                        final totalAssets = productStockValue +
                            rawStockValue +
                            totalReceivable;
                        final totalLiabilities = totalPayable;
                        final netWorth = totalAssets - totalLiabilities;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stacked = constraints.maxWidth < 700;

                                final assetsCard = _sectionCard(
                                  title: 'Assets',
                                  color: Colors.green,
                                  rows: [
                                    _row('Product Stock Value',
                                        productStockValue),
                                    _row('Raw Material Stock Value',
                                        rawStockValue),
                                    _row('Receivable from Customers',
                                        totalReceivable),
                                  ],
                                  total: totalAssets,
                                );

                                final liabilitiesCard = _sectionCard(
                                  title: 'Liabilities',
                                  color: Colors.red,
                                  rows: [
                                    _row('Payable to Suppliers',
                                        totalPayable),
                                  ],
                                  total: totalLiabilities,
                                );

                                if (stacked) {
                                  return Column(
                                    children: [
                                      assetsCard,
                                      const SizedBox(height: 16),
                                      liabilitiesCard,
                                    ],
                                  );
                                }

                                return Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: assetsCard),
                                    const SizedBox(width: 16),
                                    Expanded(child: liabilitiesCard),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: netWorth >= 0
                                    ? Colors.blue.withOpacity(0.08)
                                    : Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text('Net Worth (Assets − Liabilities)',
                                      style: TextStyle(color: Colors.grey)),
                                  const SizedBox(height: 6),
                                  Text(
                                    netWorth.toStringAsFixed(0),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: netWorth >= 0
                                          ? Colors.blue
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _row(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value.toStringAsFixed(0),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Color color,
    required List<Widget> rows,
    required double total,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const Divider(height: 20),
          ...rows,
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                total.toStringAsFixed(0),
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}