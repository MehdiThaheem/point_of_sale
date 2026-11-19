import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/branch_filter.dart';
import '../models/employee.dart';

class EmployeeService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('employees');

  Stream<List<Employee>> streamEmployees() {
    // A Manager's login is fixed to one branch: ask Firestore for only that
    // branch's documents (the security rules require it). Admin, Counter
    // Sale etc. get everything, sorted by name as before.
    final b = lockedBranchId;
    final Query q = b == null
        ? _col.orderBy('name')
        : _col.where('branchId', isEqualTo: b);
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Employee.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();
      if (b != null) list.sort((x, y) => x.name.compareTo(y.name));
      return list;
    });
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