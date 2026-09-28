import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';

class CategoryService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('categories');

  Stream<List<Category>> streamCategories() {
    return _col.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => Category.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addCategory(Category category) async {
    await _col.add(category.toMap());
  }

  Future<void> updateCategory(String id, Category category) async {
    await _col.doc(id).update(category.toMap());
  }

  Future<void> deleteCategory(String id) async {
    await _col.doc(id).delete();
  }
}