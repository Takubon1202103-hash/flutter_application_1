import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowService {
  static final _firestore = FirebaseFirestore.instance;

  static String get _currentUid =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  static Future<void> follow(String targetUid) async {
    await _firestore
        .collection('follows')
        .doc('${_currentUid}_$targetUid')
        .set({
      'followerId': _currentUid,
      'followingId': targetUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> unfollow(String targetUid) async {
    await _firestore
        .collection('follows')
        .doc('${_currentUid}_$targetUid')
        .delete();
  }

  static Stream<bool> isFollowing(String targetUid) {
    return _firestore
        .collection('follows')
        .doc('${_currentUid}_$targetUid')
        .snapshots()
        .map((doc) => doc.exists);
  }

  static Future<int> getFollowerCount(String uid) async {
    final snap = await _firestore
        .collection('follows')
        .where('followingId', isEqualTo: uid)
        .count()
        .get();
    return snap.count ?? 0;
  }

  static Future<int> getFollowingCount(String uid) async {
    final snap = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: uid)
        .count()
        .get();
    return snap.count ?? 0;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection('users').snapshots();
  }
}
