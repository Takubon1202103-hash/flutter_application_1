import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('マイQRコード', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: user.uid,
                version: QrVersions.auto,
                size: 220,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              user.displayName ?? 'ユーザー',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'このQRコードを友達にスキャンしてもらおう',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
