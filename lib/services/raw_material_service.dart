import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/branch_filter.dart';
import '../models/raw_material.dart';

class RawMaterialService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('raw_materials');

  Stream<List<RawMaterial>> streamRawMaterials() {
    // A Manager's login is fixed to one branch: ask Firestore for only that
    // branch's documents (the security rules require it). Admin, Counter
    // Sale etc. get everything, sorted by name as before.
    final b = lockedBranchId;
    final Query q = b == null
        ? _col.orderBy('name')
        : _col.where('branchId', isEqualTo: b);
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => RawMaterial.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();
      if (b != null) list.sort((x, y) => x.name.compareTo(y.name));
      return list;
    });
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