import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String role,
    String username = '',
    String designation = '',
    // Which branch this login belongs to (Managers / Counter Sale). The
    // Firestore rules read it to decide which branch's data they may see.
    String branchId = '',
    // 'active' for accounts an admin creates; self-registered accounts are
    // 'pending' until an admin approves them.
    String status = 'active',
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'role': role,
      'designation': designation,
      'branchId': branchId,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Keeps the login's branch in step with the employee record (admin only,
  // enforced by the security rules).
  Future<void> setBranch({
    required String uid,
    required String branchId,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'branchId': branchId,
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(
      String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String phone,
    String? username,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'phone': phone,
    };
    if (username != null) data['username'] = username;
    await _firestore.collection('users').doc(uid).update(data);
  }

  Future<void> updatePhotoUrl({
    required String uid,
    required String photoUrl,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'photoUrl': photoUrl,
    });
  }

  // Updates the portal access role for a linked login account
  // (admin / employee / supplier / customer).
  Future<void> updateRole({
    required String uid,
    required String role,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'role': role,
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserProfile(
      String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // Used by the Staff Directory to also show Admin accounts, which don't
  // have their own business record collection the way Employee/Supplier/
  // Customer do — they only exist in `users`.
  Stream<List<Map<String, dynamic>>> streamUsersByRole(String role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => {...d.data(), 'uid': d.id}).toList());
  }

  // Removes the Firestore profile only. Firebase Auth doesn't allow a
  // client app to delete another user's Auth account — that needs the
  // Admin SDK on a server — so the login itself would need to be removed
  // from the Firebase console separately if it should stop working too.
  Future<void> deleteUserProfile(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }
}