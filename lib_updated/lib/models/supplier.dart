import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  final String id;
  final String name;
  final String businessName;
  final String phone;
  final String email;
  final String address;
  final String area;
  final String branchId;
  final String branchName;
  final double totalPayable;
  final String status;
  final Timestamp? createdAt;

  Supplier({
    required this.id,
    required this.name,
    this.businessName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.area = '',
    this.branchId = '',
    this.branchName = '',
    this.totalPayable = 0,
    this.status = 'active',
    this.createdAt,
  });

  factory Supplier.fromMap(String id, Map<String, dynamic> map) {
    return Supplier(
      id: id,
      name: map['name'] ?? '',
      businessName: map['businessName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      area: map['area'] ?? '',
      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',
      totalPayable: (map['totalPayable'] ?? 0).toDouble(),
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'businessName': businessName,
      'phone': phone,
      'email': email,
      'address': address,
      'area': area,
      'branchId': branchId,
      'branchName': branchName,
      'totalPayable': totalPayable,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  // See Customer.operator== for why this is needed: without it, the
  // supplier DropdownButtonFormField crashes when Firestore streams a
  // fresh snapshot while a supplier is already selected.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Supplier && other.id == id);

  @override
  int get hashCode => id.hashCode;
}