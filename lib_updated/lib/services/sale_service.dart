import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales.dart';

class SaleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('sales');

  Stream<List<Sale>> streamSales() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => Sale.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  // Simple running invoice counter — good enough for a single-till shop.
  // Under heavy concurrent use two sales could momentarily see the same
  // number; that's a tradeoff for not needing a server-side counter.
  Stream<int> streamNextInvoiceNumber() {
    return _col.snapshots().map((snap) => snap.docs.length + 1);
  }

  Stream<List<Sale>> streamSalesForCustomer(String customerId) {
    return _col
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => Sale.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  // Creates the sale, reduces product stock for each item, and
  // increases the customer's receivable balance by the due amount.
  Future<void> addSale(Sale sale) async {
    await _db.runTransaction((transaction) async {
      final saleRef = _col.doc();
      transaction.set(saleRef, sale.toMap());

      for (final item in sale.items) {
        final productRef =
        _db.collection('products').doc(item.productId);
        transaction.update(productRef, {
          'currentStock': FieldValue.increment(-item.quantity),
        });
      }

      if (sale.customerId.isNotEmpty && sale.dueAmount != 0) {
        final customerRef =
        _db.collection('customers').doc(sale.customerId);
        transaction.update(customerRef, {
          'totalReceivable': FieldValue.increment(sale.dueAmount),
        });
      }
    });
  }

  // Used by the Delete Invoice screen to look a sale up by its invoice
  // number (not its Firestore doc id) before showing/deleting it.
  Future<Sale?> findByInvoiceNumber(int invoiceNumber) async {
    final snap = await _col
        .where('invoiceNumber', isEqualTo: invoiceNumber)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return Sale.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Future<void> deleteSale(Sale sale) async {
    // Reverse the stock and receivable effects, then delete the record.
    await _db.runTransaction((transaction) async {
      for (final item in sale.items) {
        final productRef =
        _db.collection('products').doc(item.productId);
        transaction.update(productRef, {
          'currentStock': FieldValue.increment(item.quantity),
        });
      }

      if (sale.customerId.isNotEmpty && sale.dueAmount != 0) {
        final customerRef =
        _db.collection('customers').doc(sale.customerId);
        transaction.update(customerRef, {
          'totalReceivable': FieldValue.increment(-sale.dueAmount),
        });
      }

      transaction.delete(_col.doc(sale.id));
    });
  }
}