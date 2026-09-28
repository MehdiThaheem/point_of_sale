import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/branch.dart';

class BranchService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('branches');

  Stream<List<Branch>> streamBranches() {
    return _col.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => Branch.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<String> addBranchAndGetId(Branch branch) async {
    final doc = await _col.add(branch.toMap());
    return doc.id;
  }

  Future<void> updateBranch(String id, Branch branch) async {
    await _col.doc(id).update(branch.toMap());
  }

  Future<void> deleteBranch(String id) async {
    await _col.doc(id).delete();
  }
}