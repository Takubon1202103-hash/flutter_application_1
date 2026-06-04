import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class PostService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static Future<void> uploadPost(File videoFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final baseName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

    // 動画アップロード
    final videoRef = _storage.ref().child('videos/$baseName.mp4');
    await videoRef.putFile(videoFile);
    final videoUrl = await videoRef.getDownloadURL();

    // サムネ生成
    String? thumbnailUrl;
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
      );
      if (thumbPath != null) {
        final thumbRef = _storage.ref().child('thumbnails/$baseName.jpg');
        await thumbRef.putFile(File(thumbPath));
        thumbnailUrl = await thumbRef.getDownloadURL();
      }
    } catch (_) {}

    await _firestore.collection('posts').add({
      'userId': user.uid,
      'username': user.displayName ?? 'ユーザー',
      'photoUrl': user.photoURL,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
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
