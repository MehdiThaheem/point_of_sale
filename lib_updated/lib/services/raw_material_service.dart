import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/raw_material.dart';

class RawMaterialService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('raw_materials');

  Stream<List<RawMaterial>> streamRawMaterials() {
    return _col.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) =>
        RawMaterial.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addRawMaterial(RawMaterial item) async {
    await _col.add(item.toMap());
  }

  Future<void> updateRawMaterial(String id, RawMaterial item) async {
    await _col.doc(id).update(item.toMap());
  }

  Future<void> deleteRawMaterial(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> adjustStock(String id, double delta) async {
    await _col.doc(id).update({'currentStock': FieldValue.increment(delta)});
  }
}