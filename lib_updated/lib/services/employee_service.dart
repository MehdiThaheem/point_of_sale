import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee.dart';

class EmployeeService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('employees');

  Stream<List<Employee>> streamEmployees() {
    return _col.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => Employee.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  // Used by a logged-in Manager's own dashboard to find their branch and
  // other details, since they only know their uid, not their employee
  // document id.
  Stream<Employee?> streamEmployeeByUid(String uid) {
    return _col
        .where('uid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
        ? null
        : Employee.fromMap(
        snap.docs.first.id,
        snap.docs.first.data() as Map<String, dynamic>));
  }

  Future<void> addEmployee(Employee employee) async {
    await _col.add(employee.toMap());
  }

  Future<String> addEmployeeAndGetId(Employee employee) async {
    final doc = await _col.add(employee.toMap());
    return doc.id;
  }

  Future<void> updateEmployee(String id, Employee employee) async {
    await _col.doc(id).update(employee.toMap());
  }

  Future<void> deleteEmployee(String id) async {
    await _col.doc(id).delete();
  }
}