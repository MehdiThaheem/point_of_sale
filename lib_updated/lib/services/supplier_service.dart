import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier.dart';

class SupplierService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('suppliers');

  Stream<List<Supplier>> streamSuppliers() {
    return _col.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => Supplier.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<Supplier?> streamSupplierByEmail(String email) {
    if (email.isEmpty) return Stream.value(null);
    return _col.where('email', isEqualTo: email).limit(1).snapshots().map(
            (snap) => snap.docs.isEmpty
            ? null
            : Supplier.fromMap(
            snap.docs.first.id,
            snap.docs.first.data() as Map<String, dynamic>));
  }

  Future<void> addSupplier(Supplier supplier) async {
    await _col.add(supplier.toMap());
  }

  Future<void> updateSupplier(String id, Supplier supplier) async {
    await _col.doc(id).update(supplier.toMap());
  }

  Future<void> deleteSupplier(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> adjustPayable(String id, double delta) async {
    await _col.doc(id).update({'totalPayable': FieldValue.increment(delta)});
  }
}