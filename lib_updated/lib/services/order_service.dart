import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart';

class OrderService {
  final CollectionReference _col =
  FirebaseFirestore.instance.collection('orders');

  Stream<List<CustomerOrder>> streamOrders() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => CustomerOrder.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<List<CustomerOrder>> streamOrdersForCustomer(String customerUid) {
    return _col
        .where('customerUid', isEqualTo: customerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => CustomerOrder.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> placeOrder(CustomerOrder order) async {
    await _col.add(order.toMap());
  }

  Future<void> updateStatus(String id, String status) async {
    await _col.doc(id).update({'status': status});
  }

  Future<void> deleteOrder(String id) async {
    await _col.doc(id).delete();
  }
}