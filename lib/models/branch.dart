import 'package:cloud_firestore/cloud_firestore.dart';

class Branch {
  final String id;
  final String branchNumber;
  final String name;
  final String urduName;
  final String manager;
  final String contact;
  final String status;
  final String city;
  final String area;
  final String address;
  final String username;
  final String password;
  final String ntn;
  final String strn;
  final String note;
  final String logoUrl;
  final String bannerUrl;
  final Timestamp? createdAt;

  Branch({
    required this.id,
    this.branchNumber = '',
    required this.name,
    this.urduName = '',
    this.manager = '',
    this.contact = '',
    this.status = 'active',
    this.city = '',
    this.area = '',
    this.address = '',
    this.username = '',
    this.password = '',
    this.ntn = '',
    this.strn = '',
    this.note = '',
    this.logoUrl = '',
    this.bannerUrl = '',
    this.createdAt,
  });

  factory Branch.fromMap(String id, Map<String, dynamic> map) {
    return Branch(
      id: id,
      branchNumber: map['branchNumber'] ?? '',
      name: map['name'] ?? '',
      urduName: map['urduName'] ?? '',
      manager: map['manager'] ?? '',
      contact: map['contact'] ?? '',
      status: map['status'] ?? 'active',
      city: map['city'] ?? '',
      area: map['area'] ?? '',
      address: map['address'] ?? '',
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      ntn: map['ntn'] ?? '',
      strn: map['strn'] ?? '',
      note: map['note'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      bannerUrl: map['bannerUrl'] ?? '',
      createdAt: map['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branchNumber': branchNumber,
      'name': name,
      'urduName': urduName,
      'manager': manager,
      'contact': contact,
      'status': status,
      'city': city,
      'area': area,
      'address': address,
      'username': username,
      'password': password,
      'ntn': ntn,
      'strn': strn,
      'note': note,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  @override
  bool operator ==(Object other) => other is Branch && other.id == id;

  @override
  int get hashCode => id.hashCode;
}