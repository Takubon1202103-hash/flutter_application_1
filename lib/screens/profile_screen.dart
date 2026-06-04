import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/follow_service.dart';
import '../widgets/video_thumbnail_widget.dart';
import 'follow_list_screen.dart';
import 'post_detail_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // BeReal風ヘッダー（グラスモフィズム背景）
            Stack(
              children: [
                // ボケた背景画像
                if (user.photoURL != null)
                  Container(
                    height: 380,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(user.photoURL!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 380,
                    color: Colors.red.withOpacity(0.3),
                  ),

                // グラスモフィズム効果（BackdropFilter）
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),

                // プロフィール情報
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ユーザー名
                        Text(
                          user.displayName ?? 'ユーザー',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // @ユーザー名とロック
                        Row(
                          children: [
                            Text(
                              '@${(user.email?.split('@')[0]) ?? 'user'}',
                              style: const TextStyle(
                                color: Color(0xFFCCCCCC),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.lock_outline,
                              color: Color(0xFFCCCCCC),
                              size: 14,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 統計情報（フォロワー・フォロー中）
                        _StatsRow(),
                        const SizedBox(height: 16),

                        // ボタン群
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.share_outlined, size: 18),
                                label: const Text('シェア'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.15),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 50,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SettingsScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.15),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Icon(Icons.edit_outlined, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 投稿セクション
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今日のOneShot',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MyPosts(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 統計情報ウィジェット
class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<int>(
      stream: FollowService.followerCountStream(user.uid),
      builder: (context, followerSnap) {
        final followers = followerSnap.data ?? 0;
        return StreamBuilder<int>(
          stream: FollowService.followingCountStream(user.uid),
          builder: (context, followingSnap) {
            final following = followingSnap.data ?? 0;
            return Text(
              '$followers フォロワー・$following フォロー中',
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 13,
              ),
            );
          },
        );
      },
    );
  }
}

// 投稿グリッド
class _MyPosts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, postsSnap) {
        if (postsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = postsSnap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: const [
                Icon(Icons.videocam_off_outlined, color: Color(0xFF2A2A2A), size: 48),
                SizedBox(height: 12),
                Text(
                  'まだ投稿がありません',
                  style: TextStyle(color: Color(0xFF555555), fontSize: 13),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
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
                  // 動画サムネイル
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: const Color(0xFF1A1A1A),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          VideoThumbnailWidget(
                            thumbnailUrl: thumbnailUrl,
                            videoUrl: videoUrl,
                          ),
                          Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white.withOpacity(0.6),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ピン留めボタン
                  Positioned(
                    top: 6,
                    right: 6,
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

// ピン留めボタンウィジェット
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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Icon(
              isPinned ? Icons.bookmark : Icons.bookmark_outline,
              color: isPinned ? Colors.red : Colors.white70,
              size: 14,
            ),
          ),
        );
      },
    );
  }
}
