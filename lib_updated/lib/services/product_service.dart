import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

class ProductService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('products');

  Stream<List<Product>> streamProducts() {
    return _col.orderBy('name').snapshots().map((snap) => snap.docs
        .map((d) => Product.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addProduct(Product product) async {
    await _col.add(product.toMap());
  }

  Future<void> updateProduct(String id, Product product) async {
    await _col.doc(id).update(product.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> adjustStock(String id, double delta) async {
    await _col.doc(id).update({'currentStock': FieldValue.increment(delta)});
  }
}