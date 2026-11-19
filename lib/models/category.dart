import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;
  final String urduName;
  final String description;
  final String status; // active / inactive
  final Timestamp? createdAt;

  Category({
    required this.id,
    required this.name,
    this.urduName = '',
    this.description = '',
    this.status = 'active',
    this.createdAt,
  });

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    return Category(
      id: id,
      name: map['name'] ?? '',
      urduName: map['urduName'] ?? '',
      description: map['description'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'urduName': urduName,
      'description': description,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}