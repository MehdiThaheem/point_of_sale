import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String businessName;
  final String phone;
  final String email;
  final String address;
  final String area;
  final String branchId;
  final String branchName;
  final double totalReceivable;
  final String status;
  final Timestamp? createdAt;

  Customer({
    required this.id,
    required this.name,
    this.businessName = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.area = '',
    this.branchId = '',
    this.branchName = '',
    this.totalReceivable = 0,
    this.status = 'active',
    this.createdAt,
  });

  factory Customer.fromMap(String id, Map<String, dynamic> map) {
    return Customer(
      id: id,
      name: map['name'] ?? '',
      businessName: map['businessName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      area: map['area'] ?? '',
      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',
      totalReceivable: (map['totalReceivable'] ?? 0).toDouble(),
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
      'totalReceivable': totalReceivable,
      'status': status,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  // Every time a StreamBuilder rebuilds, Firestore hands back brand new
  // Customer instances even for unchanged data. Without this, a
  // DropdownButtonFormField<Customer> throws "There should be exactly one
  // item..." because its previously-selected value (an old instance) no
  // longer matches (by reference) anything in the new list. Comparing by
  // id fixes that.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Customer && other.id == id);

  @override
  int get hashCode => id.hashCode;
}