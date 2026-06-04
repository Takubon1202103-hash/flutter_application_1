import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PostService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static Future<void> uploadPost(File videoFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final ref = _storage.ref().child('videos/$fileName');

    await ref.putFile(videoFile);
    final videoUrl = await ref.getDownloadURL();

    await _firestore.collection('posts').add({
      'userId': user.uid,
      'username': user.displayName ?? 'ユーザー',
      'photoUrl': user.photoURL,
      'videoUrl': videoUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> get postsStream =>
      _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots();

  static Future<bool> hasPostedToday() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final snapshot = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: user.uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}
