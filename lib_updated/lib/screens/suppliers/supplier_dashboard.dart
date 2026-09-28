import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/purchase.dart';
import '../../models/supplier.dart';
import '../../services/auth_service.dart';
import '../../services/purchase_service.dart';
import '../../services/supplier_service.dart';
import '../../services/user_service.dart';

class SupplierDashboard extends StatefulWidget {
  const SupplierDashboard({super.key});

  @override
  State<SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<SupplierDashboard> {
  final AuthService _authService = AuthService();
  final SupplierService _supplierService = SupplierService();
  final PurchaseService _purchaseService = PurchaseService();
  final UserService _userService = UserService();

  Future<void> _logout() async {
    await _authService.logout();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Delivery Boy Portal'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: StreamBuilder<Supplier?>(
        stream: _supplierService.streamSupplierByEmail(email),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final supplier = snapshot.data;

          if (supplier == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link_off,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Signed in as $email',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your account is not yet linked to a supplier '
                          'profile. Ask the company admin to make sure this '
                          'email matches the one on your supplier record.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 26,
                            child: Icon(Icons.local_shipping_outlined),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supplier.businessName.isEmpty
                                      ? supplier.name
                                      : supplier.businessName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                StreamBuilder<
                                    DocumentSnapshot<Map<String, dynamic>>>(
                                  stream: FirebaseAuth
                                      .instance.currentUser ==
                                      null
                                      ? const Stream.empty()
                                      : _userService.streamUserProfile(
                                      FirebaseAuth
                                          .instance.currentUser!.uid),
                                  builder: (context, userSnapshot) {
                                    final name = userSnapshot.data
                                        ?.data()?['name'] as String?;
                                    return Text(
                                      (name != null && name.isNotEmpty)
                                          ? name
                                          : email,
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: supplier.totalPayable > 0
                              ? Colors.red.withOpacity(0.08)
                              : Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Outstanding balance we owe you',
                                style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 6),
                            Text(
                              supplier.totalPayable.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: supplier.totalPayable > 0
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Purchase History',
                  style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<Purchase>>(
                  stream: _purchaseService
                      .streamPurchasesForSupplier(supplier.id),
                  builder: (context, purchaseSnapshot) {
                    if (purchaseSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final purchases = purchaseSnapshot.data ?? [];

                    if (purchases.isEmpty) {
                      return const Text('No purchase history yet.',
                          style: TextStyle(color: Colors.grey));
                    }

                    return Column(
                      children: purchases.map((purchase) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Total: ${purchase.totalAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Due: ${purchase.dueAmount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: purchase.dueAmount > 0
                                            ? Colors.red
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ...purchase.items.map((item) => Text(
                                    '${item.itemName} x${item.quantity}',
                                    style: const TextStyle(
                                        color: Colors.grey))),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}