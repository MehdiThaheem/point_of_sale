import 'package:cloud_firestore/cloud_firestore.dart';
import 'sales.dart';

// A parked/held sale — a cashier can save the current cart as a
// quotation and come back to it later (even after closing the app,
// since this is stored in Firestore, not just in memory).
class Quotation {
  final String id;
  final String customerId;
  final String customerName;
  final String poNumber;
  final List<SaleItem> items;
  final double discount;
  final bool discountIsPercent;
  final Timestamp? createdAt;

  Quotation({
    required this.id,
    this.customerId = '',
    required this.customerName,
    this.poNumber = '',
    required this.items,
    this.discount = 0,
    this.discountIsPercent = false,
    this.createdAt,
  });

  double get total => items.fold(0, (sum, i) => sum + i.subtotal);

  factory Quotation.fromMap(String id, Map<String, dynamic> map) {
    return Quotation(
      id: id,
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      poNumber: map['poNumber'] ?? '',
      items: ((map['items'] ?? []) as List)
          .map((e) => SaleItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      discount: (map['discount'] ?? 0).toDouble(),
      discountIsPercent: map['discountIsPercent'] ?? false,
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'poNumber': poNumber,
      'items': items.map((e) => e.toMap()).toList(),
      'discount': discount,
      'discountIsPercent': discountIsPercent,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}