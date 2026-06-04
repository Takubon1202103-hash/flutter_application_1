import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/follow_service.dart';

enum FollowListType { followers, following }

class FollowListScreen extends StatelessWidget {
  final String uid;
  final FollowListType type;

  const FollowListScreen({super.key, required this.uid, required this.type});

  @override
  Widget build(BuildContext context) {
    final title = type == FollowListType.followers ? 'フォロワー' : 'フォロー中';

    final stream = type == FollowListType.followers
        ? FirebaseFirestore.instance
            .collection('follows')
            .where('followingId', isEqualTo: uid)
            .snapshots()
        : FirebaseFirestore.instance
            .collection('follows')
            .where('followerId', isEqualTo: uid)
            .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, color: Color(0xFF333333), size: 56),
                  const SizedBox(height: 16),
                  Text(
                    type == FollowListType.followers ? 'まだフォロワーがいません' : 'まだフォローしていません',
                    style: const TextStyle(color: Color(0xFF666666), fontSize: 14),
                  ),
                ],
              ),
            );
          }

          // フォロワー: followerId のユーザー情報を取得
          // フォロー中: followingId のユーザー情報を取得
          final userIds = docs.map((d) {
            return type == FollowListType.followers
                ? d.data()['followerId'] as String
                : d.data()['followingId'] as String;
          }).toList();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: userIds.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E1E1E), height: 1),
            itemBuilder: (context, index) => _UserTile(uid: userIds[index]),
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String uid;
  const _UserTile({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(
            leading: CircleAvatar(backgroundColor: Color(0xFF1A1A1A)),
            title: Text('...', style: TextStyle(color: Colors.white)),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final name = data['displayName'] as String? ?? 'ユーザー';
        final photoUrl = data['photoUrl'] as String?;

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
          title: Text(name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          trailing: _FollowButton(targetUid: uid),
        );
      },
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
