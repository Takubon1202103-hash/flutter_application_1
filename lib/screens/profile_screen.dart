import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/follow_service.dart';
import '../widgets/video_thumbnail_widget.dart';
import 'follow_list_screen.dart';
import 'notifications_screen.dart';
import 'post_detail_screen.dart';
import 'settings_screen.dart';
import 'today_posts_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
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
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
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
                        const SizedBox(height: 12),

                        // プロフィール挨拶
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .snapshots(),
                          builder: (context, snap) {
                            final bio = (snap.data?.data() as Map<String, dynamic>?)
                                ?['bio'] as String? ?? '';
                            if (bio.isEmpty) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                bio,
                                style: const TextStyle(
                                  color: Color(0xFFCCCCCC),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),

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

// 今日の最新投稿1件表示
class _MyPosts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, postsSnap) {
        if (postsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = postsSnap.data?.docs ?? [];

        // 今日の投稿のみをフィルタリング
        final todayDocs = allDocs.where((doc) {
          final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
          if (createdAt == null) return false;
          return createdAt.isAfter(startOfDay) && createdAt.isBefore(endOfDay.add(const Duration(days: 1)));
        }).toList();

        if (todayDocs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: const [
                Icon(Icons.videocam_off_outlined, color: Color(0xFF2A2A2A), size: 48),
                SizedBox(height: 12),
                Text(
                  '今日の投稿がありません',
                  style: TextStyle(color: Color(0xFF555555), fontSize: 13),
                ),
              ],
            ),
          );
        }

        final data = todayDocs[0].data();
        final videoUrl = data['videoUrl'] as String?;
        final thumbnailUrl = data['thumbnailUrl'] as String?;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TodayPostsScreen(),
              ),
            );
          },
          child: Container(
            height: 300,
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
                      Icons.play_circle_outlined,
                      color: Colors.white.withOpacity(0.7),
                      size: 56,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

