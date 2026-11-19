import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }
}

class CustomerOrder {
  final String id;
  final String customerUid; // Firebase Auth uid of the customer who placed it
  final String customerName;
  final List<OrderItem> items;
  final double totalAmount;
  final String status; // pending / approved / rejected / completed
  final Timestamp? createdAt;

  CustomerOrder({
    required this.id,
    required this.customerUid,
    required this.customerName,
    required this.items,
    required this.totalAmount,
    this.status = 'pending',
    this.createdAt,
  });

  factory CustomerOrder.fromMap(String id, Map<String, dynamic> map) {
    return CustomerOrder(
      id: id,
      customerUid: map['customerUid'] ?? '',
      customerName: map['customerName'] ?? '',
      items: ((map['items'] ?? []) as List)
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerUid': customerUid,
      'customerName': customerName,
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}