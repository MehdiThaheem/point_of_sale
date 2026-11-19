import 'package:cloud_firestore/cloud_firestore.dart';

class Employee {
  final String id;
  final String uid; // linked auth uid, empty if not yet linked to a login
  final String name;
  final String email;
  final String phone;
  final String position;
  final double salary;
  final String status; // active / inactive
  final String cnic;
  final String qualification;
  final String address;
  final String photoUrl;
  final String branchId;
  final String branchName;
  final Timestamp? hireDate;
  final Timestamp? createdAt;

  Employee({
    required this.id,
    this.uid = '',
    required this.name,
    this.email = '',
    this.phone = '',
    this.position = '',
    this.salary = 0,
    this.status = 'active',
    this.cnic = '',
    this.qualification = '',
    this.address = '',
    this.photoUrl = '',
    this.branchId = '',
    this.branchName = '',
    this.hireDate,
    this.createdAt,
  });

  factory Employee.fromMap(String id, Map<String, dynamic> map) {
    return Employee(
      id: id,
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      position: map['position'] ?? '',
      salary: (map['salary'] ?? 0).toDouble(),
      status: map['status'] ?? 'active',
      cnic: map['cnic'] ?? '',
      qualification: map['qualification'] ?? '',
      address: map['address'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      branchId: map['branchId'] ?? '',
      branchName: map['branchName'] ?? '',
      hireDate: map['hireDate'],
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'position': position,
      'salary': salary,
      'status': status,
      'cnic': cnic,
      'qualification': qualification,
      'address': address,
      'photoUrl': photoUrl,
      'branchId': branchId,
      'branchName': branchName,
      'hireDate': hireDate,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  // See Customer.operator== for why this is needed: without it, the
  // employee DropdownButtonFormField (Generate Salary screen) crashes
  // when Firestore streams a fresh snapshot while one is selected.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Employee && other.id == id);

  @override
  int get hashCode => id.hashCode;
}