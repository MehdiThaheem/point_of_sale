import 'package:cloud_firestore/cloud_firestore.dart';

class Brand {
  final String id;
  final String name;
  final String description;
  final String status;
  final Timestamp? createdAt;

  Brand({
    required this.id,
    required this.name,
    this.description = '',
    this.status = 'active',
    this.createdAt,
  });

  factory Brand.fromMap(String id, Map<String, dynamic> map) {
    return Brand(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  @override
  bool operator ==(Object other) => other is Brand && other.id == id;

  @override
  int get hashCode => id.hashCode;
}