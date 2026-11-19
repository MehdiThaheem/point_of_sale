import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/brand.dart';

class BrandService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('brands');

  Stream<List<Brand>> streamBrands() {
    return _col.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => Brand.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addBrand(Brand brand) async {
    await _col.add(brand.toMap());
  }

  Future<void> updateBrand(String id, Brand brand) async {
    await _col.doc(id).update(brand.toMap());
  }

  Future<void> deleteBrand(String id) async {
    await _col.doc(id).delete();
  }
}