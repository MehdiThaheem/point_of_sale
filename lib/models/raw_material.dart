import 'package:cloud_firestore/cloud_firestore.dart';

class RawMaterial {
  final String id;
  final String name;
  final String unit;
  final double currentStock;
  final double minStock;
  final double costPerUnit;

  // Branch this material belongs to. Old records don't have one, so they
  // default to '' and only show under "All Branches" until edited.
  final String branchId;
  final String branchName;

  final Timestamp? createdAt;

  RawMaterial({
    required this.id,
    required this.name,
    this.unit = 'pcs',
    this.currentStock = 0,
    this.minStock = 0,
    this.costPerUnit = 0,
    this.branchId = '',
    this.branchName = '',
    this.createdAt,
  });

  bool get isLowStock => currentStock <= minStock;

  factory RawMaterial.fromMap(String id, Map<String, dynamic> map) {
    return RawMaterial(
      id: id,
      name: map['name'] ?? '',
      unit: map['unit'] ?? 'pcs',
      currentStock: (map['currentStock'] ?? 0).toDouble(),
      minStock: (map['minStock'] ?? 0).toDouble(),
      costPerUnit: (map['costPerUnit'] ?? 0).toDouble(),
      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'currentStock': currentStock,
      'minStock': minStock,
      'costPerUnit': costPerUnit,
      'branchId': branchId,
      'branchName': branchName,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}