import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class PostService {
  static final _firestore = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static Future<void> uploadPost(
    File videoFile, {
    bool isLate = false,
    File? frontVideoFile,
    String? locationName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final baseName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    // バックカメラ動画
    final videoRef = _storage.ref().child('videos/$baseName.mp4');
    await videoRef.putFile(videoFile);
    final videoUrl = await videoRef.getDownloadURL();

    // フロントカメラ動画（デュアルモード時）
    String? frontVideoUrl;
    if (frontVideoFile != null) {
      final frontRef = _storage.ref().child('videos/${baseName}_front.mp4');
      await frontRef.putFile(frontVideoFile);
      frontVideoUrl = await frontRef.getDownloadURL();
    }

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
      'frontVideoUrl': frontVideoUrl,
      'thumbnailUrl': thumbnailUrl,
      'isLate': isLate,
      'locationName': locationName,
      'postedAt': Timestamp.fromDate(now),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> get postsStream =>
      _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots();
}
