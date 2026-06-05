import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn();

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential?> signInWithGoogle() async {
    UserCredential? credential;

    if (kIsWeb) {
      credential = await _auth.signInWithPopup(GoogleAuthProvider());
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      credential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
    }

    if (credential?.user != null) {
      await _saveUser(credential!.user!);
      await _initializeNotifications(credential!.user!.uid);
    }
    return credential;
  }

  static Future<void> _saveUser(User user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'displayName': user.displayName ?? 'ユーザー',
      'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
      'postLimit': 6,
      'isPenalized': false,
      'penaltyExpireAt': null,
    }, SetOptions(merge: true));
  }

  static Future<void> _initializeNotifications(String uid) async {
    final today = DateTime.now();
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(dateKey)
        .set({
          'sentAt': [],
          'postedAt': null,
          'isOnTime': false,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  static Future<void> signOut() async {
    if (kIsWeb) {
      await _auth.signOut();
      return;
    }
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}
