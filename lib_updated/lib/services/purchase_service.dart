import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/purchase.dart';

class PurchaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('purchases');

  Stream<List<Purchase>> streamPurchases() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) =>
        Purchase.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<List<Purchase>> streamPurchasesForSupplier(String supplierId) {
    return _col
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) =>
        Purchase.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> addPurchase(Purchase purchase) async {
    await _db.runTransaction((transaction) async {
      final purchaseRef = _col.doc();
      transaction.set(purchaseRef, purchase.toMap());

      for (final item in purchase.items) {
        final collectionName =
        item.itemType == 'raw_material' ? 'raw_materials' : 'products';
        final itemRef = _db.collection(collectionName).doc(item.itemId);
        transaction
            .update(itemRef, {'currentStock': FieldValue.increment(item.quantity)});
      }

      if (purchase.supplierId.isNotEmpty && purchase.dueAmount != 0) {
        final supplierRef =
        _db.collection('suppliers').doc(purchase.supplierId);
        transaction.update(
            supplierRef, {'totalPayable': FieldValue.increment(purchase.dueAmount)});
      }
    });
  }

  Future<void> deletePurchase(Purchase purchase) async {
    await _db.runTransaction((transaction) async {
      for (final item in purchase.items) {
        final collectionName =
        item.itemType == 'raw_material' ? 'raw_materials' : 'products';
        final itemRef = _db.collection(collectionName).doc(item.itemId);
        transaction.update(
            itemRef, {'currentStock': FieldValue.increment(-item.quantity)});
      }

      if (purchase.supplierId.isNotEmpty && purchase.dueAmount != 0) {
        final supplierRef =
        _db.collection('suppliers').doc(purchase.supplierId);
        transaction.update(supplierRef,
            {'totalPayable': FieldValue.increment(-purchase.dueAmount)});
      }

      transaction.delete(_col.doc(purchase.id));
    });
  }
}