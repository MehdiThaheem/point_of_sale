import 'package:flutter/material.dart';
import '../../models/customer.dart';
import '../../models/supplier.dart';
import '../../services/customer_service.dart';
import '../../services/supplier_service.dart';

class PartiesReportScreen extends StatefulWidget {
  const PartiesReportScreen({super.key});

  @override
  State<PartiesReportScreen> createState() => _PartiesReportScreenState();
}

class _PartiesReportScreenState extends State<PartiesReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CustomerService _customerService = CustomerService();
  final SupplierService _supplierService = SupplierService();

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
          'Parties Report',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Outstanding balances for every customer and supplier.',
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
              Tab(text: 'Customers (Receivable)'),
              Tab(text: 'Suppliers (Payable)'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCustomersTab(),
              _buildSuppliersTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomersTab() {
    return StreamBuilder<List<Customer>>(
      stream: _customerService.streamCustomers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final customers = snapshot.data ?? [];

        if (customers.isEmpty) {
          return const Center(
            child:
            Text('No customers yet.', style: TextStyle(color: Colors.grey)),
          );
        }

        final total = customers.fold<double>(
            0, (sum, c) => sum + c.totalReceivable);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryBar('Total Receivable: ${total.toStringAsFixed(0)}',
                Colors.orange),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final c = customers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.person_outline, size: 18)),
                      title: Text(c.name),
                      subtitle: Text(c.phone.isEmpty ? 'No phone' : c.phone),
                      trailing: Text(
                        c.totalReceivable.toStringAsFixed(0),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: c.totalReceivable > 0
                              ? Colors.red
                              : Colors.grey,
                        ),
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

  Widget _buildSuppliersTab() {
    return StreamBuilder<List<Supplier>>(
      stream: _supplierService.streamSuppliers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final suppliers = snapshot.data ?? [];

        if (suppliers.isEmpty) {
          return const Center(
            child:
            Text('No suppliers yet.', style: TextStyle(color: Colors.grey)),
          );
        }

        final total =
        suppliers.fold<double>(0, (sum, s) => sum + s.totalPayable);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _summaryBar(
                'Total Payable: ${total.toStringAsFixed(0)}', Colors.red),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: suppliers.length,
                itemBuilder: (context, index) {
                  final s = suppliers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                          child:
                          Icon(Icons.local_shipping_outlined, size: 18)),
                      title: Text(s.name),
                      subtitle: Text(s.phone.isEmpty ? 'No phone' : s.phone),
                      trailing: Text(
                        s.totalPayable.toStringAsFixed(0),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                          s.totalPayable > 0 ? Colors.red : Colors.grey,
                        ),
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

  Widget _summaryBar(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.w600, color: color)),
    );
  }
}