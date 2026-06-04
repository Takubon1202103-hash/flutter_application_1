import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'camera_screen.dart';

class _PostData {
  final String id;
  final String username;
  final Color avatarColor;
  final Color videoColor;
  final String timeAgo;
  final bool isOwn;

  const _PostData({
    required this.id,
    required this.username,
    required this.avatarColor,
    required this.videoColor,
    required this.timeAgo,
    this.isOwn = false,
  });
}

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

  final List<_PostData> _posts = [
    _PostData(
      id: '1',
      username: '龍馬',
      avatarColor: Color(0xFF2979FF),
      videoColor: Color(0xFF0D1B3E),
      timeAgo: '2分前',
    ),
    _PostData(
      id: '2',
      username: '翔',
      avatarColor: Color(0xFF00C853),
      videoColor: Color(0xFF0A2B0A),
      timeAgo: '5分前',
    ),
    _PostData(
      id: '3',
      username: '健人',
      avatarColor: Color(0xFFFF6D00),
      videoColor: Color(0xFF2B1200),
      timeAgo: '8分前',
    ),
  ];

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
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
    if (result != null && mounted) {
      _countdownTimer?.cancel();
      setState(() {
        _hasPosted = true;
        _timerActive = false;
        _posts.insert(
          0,
          const _PostData(
            id: 'own',
            username: 'あなた',
            avatarColor: Colors.red,
            videoColor: Color(0xFF2D0000),
            timeAgo: 'たった今',
            isOwn: true,
          ),
        );
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
              label: const Text(
                '通知を受け取る',
                style: TextStyle(fontSize: 13),
              ),
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
              letterSpacing: 2,
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
                letterSpacing: 0.5,
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        final locked = !_hasPosted && !post.isOwn;
        return _PostCard(post: post, locked: locked);
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  final _PostData post;
  final bool locked;

  const _PostCard({required this.post, required this.locked});

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
          _buildVideoArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: post.avatarColor,
            child: Text(
              post.username[0],
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
                post.username,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                post.timeAgo,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (post.isOwn) ...[
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

  Widget _buildVideoArea() {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  post.videoColor,
                  post.videoColor.withOpacity(0.4),
                ],
              ),
            ),
            child: post.isOwn
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Colors.white38, size: 52),
                      SizedBox(height: 12),
                      Text(
                        '投稿済み',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    ],
                  )
                : const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white12,
                      size: 64,
                    ),
                  ),
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
                        '${post.username}の動画を見るには投稿しよう',
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
    );
  }
}
