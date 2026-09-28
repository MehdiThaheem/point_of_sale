import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';

class CustomerService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('customers');

  Stream<List<Customer>> streamCustomers() {
    return _col.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => Customer.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
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