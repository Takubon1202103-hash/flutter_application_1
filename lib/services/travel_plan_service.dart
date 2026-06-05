import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/travel_plan.dart';

class TravelPlanService {
  static final _db = FirebaseFirestore.instance;

  // プラン作成
  static Future<String> createPlan({
    required String title,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String description,
    required bool isPublic,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final ref = await _db.collection('travel_plans').add({
      'title': title,
      'destination': destination,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'description': description,
      'isPublic': isPublic,
      'authorId': user.uid,
      'authorName': user.displayName ?? 'ユーザー',
      'authorPhotoUrl': user.photoURL,
      'likeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // スポット追加
  static Future<void> addSpot(String planId, TravelSpot spot) async {
    await _db
        .collection('travel_plans')
        .doc(planId)
        .collection('spots')
        .add(spot.toMap());
  }

  // スポット削除
  static Future<void> deleteSpot(String planId, String spotId) async {
    await _db
        .collection('travel_plans')
        .doc(planId)
        .collection('spots')
        .doc(spotId)
        .delete();
  }

  // プラン削除
  static Future<void> deletePlan(String planId) async {
    final spotsSnap = await _db
        .collection('travel_plans')
        .doc(planId)
        .collection('spots')
        .get();
    final batch = _db.batch();
    for (final d in spotsSnap.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_db.collection('travel_plans').doc(planId));
    await batch.commit();
  }

  // 自分のプラン一覧
  static Stream<QuerySnapshot<Map<String, dynamic>>> myPlansStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('travel_plans')
        .where('authorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // 公開プラン一覧（みんなの旅行プラン）
  static Stream<QuerySnapshot<Map<String, dynamic>>> publicPlansStream() {
    return _db
        .collection('travel_plans')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  // スポット一覧
  static Stream<QuerySnapshot<Map<String, dynamic>>> spotsStream(String planId) {
    return _db
        .collection('travel_plans')
        .doc(planId)
        .collection('spots')
        .orderBy('order')
        .snapshots();
  }

  // いいね切り替え
  static Future<void> toggleLike(String planId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final likeRef = _db
        .collection('travel_plans')
        .doc(planId)
        .collection('likes')
        .doc(uid);

    final planRef = _db.collection('travel_plans').doc(planId);

    final likeDoc = await likeRef.get();
    if (likeDoc.exists) {
      await likeRef.delete();
      await planRef.update({'likeCount': FieldValue.increment(-1)});
    } else {
      await likeRef.set({'createdAt': FieldValue.serverTimestamp()});
      await planRef.update({'likeCount': FieldValue.increment(1)});
    }
  }

  static Stream<bool> isLikedStream(String planId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _db
        .collection('travel_plans')
        .doc(planId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists);
  }
}
