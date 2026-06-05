import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class ShotState extends ChangeNotifier {
  static const int lateThresholdMinutes = 2;

  bool _hasPostedToday = false;
  DateTime? _postedAt;
  bool _isLate = false;
  DateTime? _shotTime;
  bool _initialized = false;

  bool get hasPostedToday => _hasPostedToday;
  DateTime? get postedAt => _postedAt;
  bool get isLate => _isLate;
  DateTime? get shotTime => _shotTime;
  bool get initialized => _initialized;

  // 遅刻ラベル（タイムライン・プロフィール表示用）
  String lateLabel(DateTime? postTime) {
    if (_shotTime == null || postTime == null) return '';
    final diff = postTime.difference(_shotTime!);
    if (diff.inMinutes <= lateThresholdMinutes) return '';
    if (diff.inHours >= 1) return '${diff.inHours}時間遅れで投稿';
    return '${diff.inMinutes}分遅れで投稿';
  }

  // 今日のShotTimeウィンドウ内か（2分以内 = 通常投稿）
  bool get isInShotWindow {
    if (_shotTime == null) return false;
    final diff = DateTime.now().difference(_shotTime!);
    return diff.inSeconds >= 0 && diff.inMinutes < lateThresholdMinutes;
  }

  Future<void> initialize() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    // 今日の投稿を確認（orderByなしでWHEREのみ）
    final postSnap = await FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .get();

    final todayPosts = postSnap.docs.where((d) {
      final ts = d.data()['createdAt'] as Timestamp?;
      final dt = ts?.toDate();
      return dt != null && dt.isAfter(startOfDay);
    }).toList();

    if (todayPosts.isNotEmpty) {
      final data = todayPosts.first.data();
      _hasPostedToday = true;
      _postedAt = (data['createdAt'] as Timestamp?)?.toDate();
      _isLate = data['isLate'] as bool? ?? false;
    }

    _shotTime = await _fetchShotTime();
    await _registerFCMToken(uid);
    _initialized = true;
    notifyListeners();
  }

  Future<void> _registerFCMToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token)
          .set({'registeredAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('FCM トークン登録エラー: $e');
    }
  }

  Future<DateTime?> _fetchShotTime() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('daily')
          .get();
      final ts = doc.data()?['shotTime'] as Timestamp?;
      return ts?.toDate();
    } catch (_) {
      return null;
    }
  }

  // 「通知を受け取る」ボタンを押した時に呼ぶ
  Future<void> startShotTimer() async {
    final now = DateTime.now();
    _shotTime = now;
    await FirebaseFirestore.instance
        .collection('config')
        .doc('daily')
        .set({'shotTime': Timestamp.fromDate(now)}, SetOptions(merge: true));
    notifyListeners();
  }

  // 投稿完了時に呼ぶ
  void markPosted(DateTime postedAt) {
    _hasPostedToday = true;
    _postedAt = postedAt;
    _isLate = calculateIsLate(postedAt);
    notifyListeners();
  }

  bool calculateIsLate(DateTime postedAt) {
    if (_shotTime == null) return false;
    return postedAt.difference(_shotTime!).inMinutes > lateThresholdMinutes;
  }

  // ログアウト時にリセット
  void reset() {
    _hasPostedToday = false;
    _postedAt = null;
    _isLate = false;
    _shotTime = null;
    _initialized = false;
    notifyListeners();
  }
}
