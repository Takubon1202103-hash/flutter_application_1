import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/follow_service.dart';
import 'my_qr_screen.dart';
import 'qr_scanner_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          '友達',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.white),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyQrScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const QrScannerScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ユーザー名で検索',
                hintStyle: const TextStyle(color: Color(0xFF555555)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF555555)),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FollowService.getUsersStream(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((d) {
                  if (d.id == currentUid) return false;
                  if (_query.isEmpty) return true;
                  final name = (d.data()['displayName'] as String? ?? '').toLowerCase();
                  return name.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('ユーザーが見つかりません', style: TextStyle(color: Color(0xFF666666))),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Color(0xFF1E1E1E), height: 1),
                  itemBuilder: (context, index) {
                    final data = filtered[index].data();
                    final uid = filtered[index].id;
                    return _UserTile(uid: uid, data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;

  const _UserTile({required this.uid, required this.data});

  @override
  Widget build(BuildContext context) {
    final photoUrl = data['photoUrl'] as String?;
    final name = data['displayName'] as String? ?? 'ユーザー';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 24,
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
        backgroundColor: Colors.red,
        child: photoUrl == null
            ? Text(name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            : null,
      ),
      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      trailing: _FollowButton(targetUid: uid),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final String targetUid;
  const _FollowButton({required this.targetUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: FollowService.isFollowing(targetUid),
      builder: (context, snapshot) {
        final following = snapshot.data ?? false;

        return GestureDetector(
          onTap: () async {
            if (following) {
              await FollowService.unfollow(targetUid);
            } else {
              await FollowService.follow(targetUid);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: following ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              following ? 'フォロー中' : 'フォロー',
              style: TextStyle(
                color: following ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
  }
}
