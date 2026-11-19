import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/branch_filter.dart';
import '../models/customer.dart';

class CustomerService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('customers');

  Stream<List<Customer>> streamCustomers() {
    // A Manager's login is fixed to one branch: ask Firestore for only that
    // branch's documents (the security rules require it). Admin, Counter
    // Sale etc. get everything, sorted by name as before.
    final b = lockedBranchId;
    final Query q = b == null
        ? _col.orderBy('name')
        : _col.where('branchId', isEqualTo: b);
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Customer.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();
      if (b != null) list.sort((x, y) => x.name.compareTo(y.name));
      return list;
    });
  }

  Stream<Customer?> streamCustomerByEmail(String email) {
    if (email.isEmpty) return Stream.value(null);
    return _col.where('email', isEqualTo: email).limit(1).snapshots().map(
            (snap) => snap.docs.isEmpty
            ? null
            : Customer.fromMap(
            snap.docs.first.id,
            snap.docs.first.data() as Map<String, dynamic>));
  }

  Future<void> addCustomer(Customer customer) async {
    await _col.add(customer.toMap());
  }

  Future<void> updateCustomer(String id, Customer customer) async {
    await _col.doc(id).update(customer.toMap());
  }

  Future<void> deleteCustomer(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> adjustReceivable(String id, double delta) async {
    await _col.doc(id).update({'totalReceivable': FieldValue.increment(delta)});
  }
}