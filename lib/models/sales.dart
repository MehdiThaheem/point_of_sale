import 'package:cloud_firestore/cloud_firestore.dart';

class SaleItem {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get subtotal => quantity * unitPrice;

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
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

class Sale {
  final String id;
  final int invoiceNumber;

  final String customerId;
  final String customerName;

  final String branchId;
  final String branchName;

  final String poNumber;
  final List<SaleItem> items;

  final double totalAmount;
  final double discount;
  final double paidAmount;

  final String paymentMethod;
  final String cashierName;
  final Timestamp? createdAt;

  Sale({
    required this.id,
    this.invoiceNumber = 0,

    required this.customerId,
    required this.customerName,

    this.branchId = '',
    this.branchName = '',

    this.poNumber = '',
    required this.items,

    required this.totalAmount,
    this.discount = 0,
    required this.paidAmount,

    this.paymentMethod = 'Cash',
    this.cashierName = '',
    this.createdAt,
  });

  double get netAmount => totalAmount - discount;

  double get dueAmount => netAmount - paidAmount;

  factory Sale.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    return Sale(
      id: id,

      invoiceNumber: (map['invoiceNumber'] ?? 0) is int
          ? map['invoiceNumber'] ?? 0
          : (map['invoiceNumber'] ?? 0).toInt(),

      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',

      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',

      poNumber: map['poNumber'] ?? '',

      items: ((map['items'] ?? []) as List)
          .map(
            (e) => SaleItem.fromMap(
          Map<String, dynamic>.from(e),
        ),
      )
          .toList(),

      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),

      paymentMethod: map['paymentMethod'] ?? 'Cash',
      cashierName: map['cashierName'] ?? '',

      createdAt: map['createdAt'] is Timestamp
          ? map['createdAt']
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceNumber': invoiceNumber,

      'customerId': customerId,
      'customerName': customerName,

      'branchId': branchId,
      'branchName': branchName,

      'poNumber': poNumber,

      'items': items.map((e) => e.toMap()).toList(),

      'totalAmount': totalAmount,
      'discount': discount,
      'paidAmount': paidAmount,

      'paymentMethod': paymentMethod,
      'cashierName': cashierName,

      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}