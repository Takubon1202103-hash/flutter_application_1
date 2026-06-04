import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/follow_service.dart';
import '../widgets/video_thumbnail_widget.dart';
import 'follow_list_screen.dart';
import 'post_detail_screen.dart';
import 'settings_screen.dart';
import 'video_view_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          'プロフィール',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 48,
              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              backgroundColor: Colors.red,
              child: user.photoURL == null
                  ? Text(
                      (user.displayName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              user.displayName ?? 'ユーザー',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _StatsRow(uid: user.uid),
            const SizedBox(height: 24),
            _MyPosts(uid: user.uid),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final String uid;
  const _StatsRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 投稿数
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: uid)
                .snapshots(),
            builder: (_, snap) => _StatItem(
              label: '投稿',
              value: '${snap.data?.docs.length ?? 0}',
            ),
          ),
          Container(width: 0.5, height: 32, color: const Color(0xFF2A2A2A)),
          // フォロワー数
          StreamBuilder<int>(
            stream: FollowService.followerCountStream(uid),
            builder: (context, snap) => GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FollowListScreen(uid: uid, type: FollowListType.followers),
              )),
              child: _StatItem(label: 'フォロワー', value: '${snap.data ?? 0}'),
            ),
          ),
          Container(width: 0.5, height: 32, color: const Color(0xFF2A2A2A)),
          // フォロー中
          StreamBuilder<int>(
            stream: FollowService.followingCountStream(uid),
            builder: (context, snap) => GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FollowListScreen(uid: uid, type: FollowListType.following),
              )),
              child: _StatItem(label: 'フォロー中', value: '${snap.data ?? 0}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF777777), fontSize: 12)),
      ],
    );
  }
}

class _MyPosts extends StatelessWidget {
  final String uid;
  const _MyPosts({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = [...(snapshot.data?.docs ?? [])]
          ..sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
            final bTime = (b.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
            return bTime.compareTo(aTime);
          });

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Column(
              children: [
                Icon(Icons.videocam_off_outlined, color: Color(0xFF2A2A2A), size: 56),
                SizedBox(height: 14),
                Text('まだ投稿がありません', style: TextStyle(color: Color(0xFF555555), fontSize: 14)),
              ],
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 9 / 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final videoUrl = data['videoUrl'] as String?;
            final thumbnailUrl = data['thumbnailUrl'] as String?;
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(
                      postId: docs[index].id,
                      postData: data,
                    ),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoThumbnailWidget(
                    thumbnailUrl: thumbnailUrl,
                    videoUrl: videoUrl,
                  ),
                  const Center(
                    child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 32),
                  ),
                  // ピン留めボタン
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _PinButton(postId: docs[index].id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PinButton extends StatelessWidget {
  final String postId;
  const _PinButton({required this.postId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snap) {
        final pinnedPosts = List<String>.from(
          snap.data?.get('pinnedPosts') as List<dynamic>? ?? []
        );
        final isPinned = pinnedPosts.contains(postId);

        return GestureDetector(
          onTap: () async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) return;

            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

            final pins = List<String>.from(
              userDoc.data()?['pinnedPosts'] as List<dynamic>? ?? []
            );

            if (pins.contains(postId)) {
              pins.remove(postId);
            } else {
              if (pins.length < 3) {
                pins.add(postId);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ピン留めは最大3件までです')),
                  );
                }
                return;
              }
            }

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'pinnedPosts': pins});
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPinned ? Icons.bookmark : Icons.bookmark_outline,
              color: isPinned ? Colors.red : Colors.white70,
              size: 16,
            ),
          ),
        );
      },
    );
  }
}
