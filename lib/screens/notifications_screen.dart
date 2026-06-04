import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          '通知',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toUid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          final docs = [...(snapshot.data?.docs ?? [])]
            ..sort((a, b) {
              final aTime = (a.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
              final bTime = (b.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
              return bTime.compareTo(aTime);
            });

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, color: Color(0xFF444444), size: 56),
                  SizedBox(height: 16),
                  Text('通知はありません', style: TextStyle(color: Color(0xFF666666), fontSize: 14)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Color(0xFF1E1E1E), height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final type = data['type'] as String? ?? '';
              final fromName = data['fromName'] as String? ?? 'ユーザー';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final timeAgo = _formatTimeAgo(createdAt);

              String message = '';
              IconData icon = Icons.notifications;
              if (type == 'follow') {
                message = 'があなたをフォローしました';
                icon = Icons.person_add;
              } else if (type == 'shot') {
                message = 'がOneShotを投稿しました';
                icon = Icons.videocam;
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.red, size: 22),
                ),
                title: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: fromName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: message,
                        style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                subtitle: Text(timeAgo, style: const TextStyle(color: Color(0xFF555555), fontSize: 12)),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'たった今';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
    if (diff.inHours < 24) return '${diff.inHours}時間前';
    return '${diff.inDays}日前';
  }
}
