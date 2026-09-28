import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String barcode;
  final String categoryId;
  final String categoryName;
  final String brandId;
  final String brandName;
  final String branchId;
  final String branchName;
  final String shelfLocation;
  final String unit;
  final double packSize; // items in pack, e.g. 12
  final double purchasePrice; // per-item purchase cost
  final double salePrice; // per-item selling price
  final double currentStock;
  final double minStock;
  final String description;
  final String status; // active / inactive
  final Timestamp? createdAt;

  Product({
    required this.id,
    required this.name,
    this.barcode = '',
    this.categoryId = '',
    this.categoryName = '',
    this.brandId = '',
    this.brandName = '',
    this.branchId = '',
    this.branchName = '',
    this.shelfLocation = '',
    this.unit = 'pcs',
    this.packSize = 1,
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.currentStock = 0,
    this.minStock = 0,
    this.description = '',
    this.status = 'active',
    this.createdAt,
  });

  bool get isLowStock => currentStock <= minStock;

  factory Product.fromMap(String id, Map<String, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      barcode: map['barcode'] ?? '',
      categoryId: map['categoryId'] ?? '',
      categoryName: map['categoryName'] ?? '',
      brandId: map['brandId'] ?? '',
      brandName: map['brandName'] ?? '',
      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',
      shelfLocation: map['shelfLocation'] ?? '',
      unit: map['unit'] ?? 'pcs',
      packSize: (map['packSize'] ?? 1).toDouble(),
      purchasePrice: (map['purchasePrice'] ?? 0).toDouble(),
      salePrice: (map['salePrice'] ?? 0).toDouble(),
      currentStock: (map['currentStock'] ?? 0).toDouble(),
      minStock: (map['minStock'] ?? 0).toDouble(),
      description: map['description'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'barcode': barcode,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'brandId': brandId,
      'brandName': brandName,
      'branchId': branchId,
      'branchName': branchName,
      'shelfLocation': shelfLocation,
      'unit': unit,
      'packSize': packSize,
      'purchasePrice': purchasePrice,
      'salePrice': salePrice,
      'currentStock': currentStock,
      'minStock': minStock,
      'description': description,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  // Every time a StreamBuilder rebuilds, Firestore hands back brand new
  // Product instances even for unchanged data. Without this, a
  // DropdownButtonFormField<Product> throws "There should be exactly one
  // item..." because its previously-selected value (an old instance) no
  // longer matches (by reference) anything in the new list. Comparing by
  // id fixes that.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Product && other.id == id);

  @override
  int get hashCode => id.hashCode;
}