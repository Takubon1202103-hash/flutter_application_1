import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LikeService {
  static Future<void> toggleLike(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('posts').doc(postId)
        .collection('likes').doc(uid);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }

  static Stream<bool> isLiked(String postId) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return FirebaseFirestore.instance
        .collection('posts').doc(postId)
        .collection('likes').doc(uid)
        .snapshots()
        .map((d) => d.exists);
  }

  static Stream<int> likeCount(String postId) {
    return FirebaseFirestore.instance
        .collection('posts').doc(postId)
        .collection('likes')
        .snapshots()
        .map((s) => s.docs.length);
  }
}
