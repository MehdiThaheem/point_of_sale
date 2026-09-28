import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseItem {
  final String itemType;
  final String itemId;
  final String itemName;
  final double quantity;
  final double unitCost;

  PurchaseItem({
    required this.itemType,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitCost,
  });

  double get subtotal => quantity * unitCost;

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      itemType: map['itemType'] ?? 'product',
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unitCost: (map['unitCost'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemType': itemType,
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'unitCost': unitCost,
    };
  }
}

class Purchase {
  final String id;
  final String supplierId;
  final String supplierName;
  final List<PurchaseItem> items;
  final double totalAmount;
  final double paidAmount;
  final String branchId;
  final String branchName;
  final Timestamp? createdAt;

  Purchase({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.totalAmount,
    required this.paidAmount,
    this.branchId = '',
    this.branchName = '',
    this.createdAt,
  });

  double get dueAmount => totalAmount - paidAmount;

  factory Purchase.fromMap(String id, Map<String, dynamic> map) {
    return Purchase(
      id: id,
      supplierId: map['supplierId'] ?? '',
      supplierName: map['supplierName'] ?? '',
      items: ((map['items'] ?? []) as List)
          .map((e) => PurchaseItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'branchId': branchId,
      'branchName': branchName,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}