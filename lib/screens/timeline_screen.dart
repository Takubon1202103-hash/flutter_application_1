import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/post_service.dart';
import '../services/shot_state.dart';
import '../widgets/video_thumbnail_widget.dart';
import 'camera_screen.dart';
import 'video_view_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  Future<void> _openCamera() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (result == true && mounted) {
      // ShotStateはcamera_screen側でmarkPosted済み
      setState(() {});
    }
  }

  Future<void> _startShotTimer() async {
    await context.read<ShotState>().startShotTimer();
  }

  @override
  Widget build(BuildContext context) {
    final shotState = context.watch<ShotState>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _buildAppBar(shotState),
      body: Stack(
        children: [
          _buildTimeline(shotState),
          // ロック画面: 未投稿の場合
          if (!shotState.hasPostedToday) _buildLockOverlay(),
        ],
      ),
      floatingActionButton: shotState.shotTime == null
          ? FloatingActionButton.extended(
              onPressed: _startShotTimer,
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.notifications, color: Colors.red, size: 20),
              label: const Text('通知を受け取る', style: TextStyle(fontSize: 13)),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(ShotState shotState) {
    final hasTimer = shotState.shotTime != null;

    return AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          const Text(
            'OneShot',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (hasTimer && !shotState.hasPostedToday) ...[
            const SizedBox(width: 12),
            _ShotTimerBadge(shotTime: shotState.shotTime!),
          ],
          if (shotState.hasPostedToday) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    shotState.isLate ? '遅れて投稿済み' : '投稿済み',
                    style: TextStyle(
                      color: shotState.isLate ? Colors.orange : Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ロックオーバーレイ: 未投稿時にタイムライン全体に被せる
  Widget _buildLockOverlay() {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            color: Colors.black.withOpacity(0.7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  '今日のOneShotを投稿すると、',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Text(
                  '友達の投稿が表示されます',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _openCamera,
                  icon: const Icon(Icons.videocam, size: 22),
                  label: const Text('今すぐ撮影する', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(ShotState shotState) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: PostService.postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text('まだ投稿がありません', style: TextStyle(color: Color(0xFF666666))),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final isOwn = data['userId'] == currentUserId;
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final postedAt = (data['postedAt'] as Timestamp?)?.toDate() ?? createdAt;
            final isLate = data['isLate'] as bool? ?? false;
            final lateLabel = isLate ? shotState.lateLabel(postedAt) : '';

            return _PostCard(
              username: data['username'] ?? 'ユーザー',
              photoUrl: data['photoUrl'] as String?,
              videoUrl: data['videoUrl'] as String?,
              thumbnailUrl: data['thumbnailUrl'] as String?,
              timeAgo: _formatTimeAgo(createdAt),
              isOwn: isOwn,
              isLate: isLate,
              lateLabel: lateLabel,
            );
          },
        );
      },
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

// ショットタイマーバッジ（リアルタイムカウントダウン）
class _ShotTimerBadge extends StatefulWidget {
  final DateTime shotTime;
  const _ShotTimerBadge({required this.shotTime});

  @override
  State<_ShotTimerBadge> createState() => _ShotTimerBadgeState();
}

class _ShotTimerBadgeState extends State<_ShotTimerBadge> {
  late final _timer = Stream.periodic(const Duration(seconds: 1));
  late final _sub = _timer.listen((_) { if (mounted) setState(() {}); });

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.shotTime);
    final remaining = ShotState.lateThresholdMinutes * 60 - elapsed.inSeconds;
    final isUrgent = remaining > 0 && remaining < 30;
    final isLate = remaining <= 0;

    if (isLate) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('遅刻中', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }

    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final s = (remaining % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: isUrgent ? Colors.white : const Color(0xFFAAAAAA), size: 13),
          const SizedBox(width: 4),
          Text('$m:$s', style: TextStyle(
            color: isUrgent ? Colors.white : const Color(0xFFCCCCCC),
            fontSize: 14, fontWeight: FontWeight.bold,
          )),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final String username;
  final String? photoUrl;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String timeAgo;
  final bool isOwn;
  final bool isLate;
  final String lateLabel;

  const _PostCard({
    required this.username,
    required this.photoUrl,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.timeAgo,
    required this.isOwn,
    required this.isLate,
    required this.lateLabel,
  });

  void _openVideo(BuildContext context) {
    if (videoUrl == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoViewScreen(videoUrl: videoUrl!, username: username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildVideoArea(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          photoUrl != null
              ? CircleAvatar(radius: 18, backgroundImage: NetworkImage(photoUrl!))
              : CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.red,
                  child: Text(username.isNotEmpty ? username[0] : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(username,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Row(
                  children: [
                    Text(timeAgo, style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
                    if (isLate && lateLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.4)),
                        ),
                        child: Text(lateLabel,
                            style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isOwn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: const Text('あなた', style: TextStyle(color: Colors.red, fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoArea(BuildContext context) {
    return GestureDetector(
      onTap: () => _openVideo(context),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoThumbnailWidget(thumbnailUrl: thumbnailUrl, videoUrl: videoUrl),
            const Center(
              child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 64),
            ),
          ],
        ),
      ),
    );
  }
}
