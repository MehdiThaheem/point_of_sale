import 'package:cloud_firestore/cloud_firestore.dart';

class RawMaterial {
  final String id;
  final String name;
  final String unit;
  final double currentStock;
  final double minStock;
  final double costPerUnit;
  final Timestamp? createdAt;

  RawMaterial({
    required this.id,
    required this.name,
    this.unit = 'pcs',
    this.currentStock = 0,
    this.minStock = 0,
    this.costPerUnit = 0,
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
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}