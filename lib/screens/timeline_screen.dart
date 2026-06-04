import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/post_service.dart';
import 'camera_screen.dart';
import 'video_view_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  bool _hasPosted = false;
  bool _timerActive = false;
  int _secondsRemaining = 600;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _checkIfPostedToday();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkIfPostedToday() async {
    final posted = await PostService.hasPostedToday();
    if (mounted) setState(() => _hasPosted = posted);
  }

  void _startTimer() {
    if (_timerActive) return;
    setState(() {
      _timerActive = true;
      _secondsRemaining = 600;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        timer.cancel();
        setState(() => _timerActive = false);
      }
    });
  }

  String get _timerDisplay {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _openCamera() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
    if (result == true && mounted) {
      _countdownTimer?.cancel();
      setState(() {
        _hasPosted = true;
        _timerActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_timerActive && !_hasPosted) _buildShootBanner(),
          Expanded(child: _buildTimeline()),
        ],
      ),
      floatingActionButton: !_timerActive
          ? FloatingActionButton.extended(
              onPressed: _startTimer,
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.notifications, color: Colors.red, size: 20),
              label: const Text('通知を受け取る', style: TextStyle(fontSize: 13)),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isUrgent = _timerActive && _secondsRemaining < 60;
    return AppBar(
      backgroundColor: const Color(0xFF0A0A0A),
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          const Text(
            'OneShot',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_timerActive) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isUrgent ? Colors.red : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer,
                    color: isUrgent ? Colors.white : const Color(0xFFAAAAAA),
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _timerDisplay,
                    style: TextStyle(
                      color: isUrgent ? Colors.white : const Color(0xFFCCCCCC),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

  Widget _buildShootBanner() {
    return GestureDetector(
      onTap: _openCamera,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFCC0000), Color(0xFFFF2D2D)],
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              '今すぐ撮影する',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: PostService.postsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'まだ投稿がありません',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final isOwn = data['userId'] == currentUserId;
            final locked = !_hasPosted && !isOwn;
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            final timeAgo = _formatTimeAgo(createdAt);

            return _PostCard(
              username: data['username'] ?? 'ユーザー',
              photoUrl: data['photoUrl'] as String?,
              videoUrl: data['videoUrl'] as String?,
              thumbnailUrl: data['thumbnailUrl'] as String?,
              timeAgo: timeAgo,
              isOwn: isOwn,
              locked: locked,
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

class _PostCard extends StatelessWidget {
  final String username;
  final String? photoUrl;
  final String? videoUrl;
  final String? thumbnailUrl;
  final String timeAgo;
  final bool isOwn;
  final bool locked;

  const _PostCard({
    required this.username,
    required this.photoUrl,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.timeAgo,
    required this.isOwn,
    required this.locked,
  });

  void _openVideo(BuildContext context) {
    if (locked || videoUrl == null) return;
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
              ? CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(photoUrl!),
                )
              : CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.red,
                  child: Text(
                    username.isNotEmpty ? username[0] : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                timeAgo,
                style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
              ),
            ],
          ),
          if (isOwn) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: const Text(
                'あなた',
                style: TextStyle(color: Colors.red, fontSize: 11),
              ),
            ),
          ],
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
            if (thumbnailUrl != null)
              Image.network(
                thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            else
              Container(color: const Color(0xFF111111)),
            const Center(
              child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 64),
            ),
          if (locked)
            ClipRect(

              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '投稿するとロック解除',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$usernameの動画を見るには投稿しよう',
                        style: const TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}
