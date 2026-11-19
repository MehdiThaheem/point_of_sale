import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/branch_filter.dart';
import '../models/product.dart';

class ProductService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('products');

  Stream<List<Product>> streamProducts() {
    // A Manager's login is fixed to one branch: ask Firestore for only that
    // branch's documents (the security rules require it). Admin, Counter
    // Sale etc. get everything, sorted by name as before.
    final b = lockedBranchId;
    final Query q = b == null
        ? _col.orderBy('name')
        : _col.where('branchId', isEqualTo: b);
    return q.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Product.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();
      if (b != null) list.sort((x, y) => x.name.compareTo(y.name));
      return list;
    });
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