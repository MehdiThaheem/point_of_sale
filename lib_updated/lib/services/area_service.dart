import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/area.dart';

class AreaService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('areas');

  Stream<List<Area>> streamAreas() {
    return _col.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => Area.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addArea(Area area) async {
    await _col.add(area.toMap());
  }

  Future<void> updateArea(String id, Area area) async {
    await _col.doc(id).update(area.toMap());
  }

  Future<void> deleteArea(String id) async {
    await _col.doc(id).delete();
  }
}