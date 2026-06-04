import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/like_service.dart';
import '../utils/video_filters.dart';
import 'post_detail_screen.dart';

class TodayPostsScreen extends StatefulWidget {
  const TodayPostsScreen({super.key});

  @override
  State<TodayPostsScreen> createState() => _TodayPostsScreenState();
}

class _TodayPostsScreenState extends State<TodayPostsScreen> {
  late PageController _pageController;
  final Map<int, VideoPlayerController?> _controllers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller?.dispose();
    }
    super.dispose();
  }

  void _initController(int index, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (index >= docs.length) return;
    final videoUrl = docs[index].data()['videoUrl'] as String?;
    if (videoUrl == null) return;

    if (!_controllers.containsKey(index)) {
      _controllers[index] = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      )..initialize().then((_) {
          if (mounted) setState(() {});
          _controllers[index]?.play();
        });
    }
  }

  void _onPageChanged(int page, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    _initController(page + 1, docs);
    if (page > 0) {
      _controllers[page - 1]?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          '今日の投稿',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          final allDocs = snap.data?.docs ?? [];

          // 今日の投稿のみをフィルタリング
          final docs = allDocs.where((doc) {
            final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
            if (createdAt == null) return false;
            return createdAt.isAfter(startOfDay) && createdAt.isBefore(endOfDay.add(const Duration(days: 1)));
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                '今日の投稿がありません',
                style: TextStyle(color: Color(0xFF555555), fontSize: 14),
              ),
            );
          }

          // 初回ロード時に最初のページを初期化
          if (_controllers.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initController(0, docs);
              _initController(1, docs);
            });
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (p) => _onPageChanged(p, docs),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

              return _VideoPage(
                postId: docs[index].id,
                postData: data,
                userId: data['userId'] as String? ?? '',
                controller: _controllers[index],
                username: data['username'] ?? 'ユーザー',
                photoUrl: data['photoUrl'] as String?,
                timeAgo: _formatTimeAgo(createdAt),
                caption: data['caption'] as String?,
                filterName: data['filterName'] as String?,
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

class _VideoPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final String userId;
  final VideoPlayerController? controller;
  final String username;
  final String? photoUrl;
  final String timeAgo;
  final String? caption;
  final String? filterName;

  const _VideoPage({
    required this.postId,
    required this.postData,
    required this.userId,
    required this.controller,
    required this.username,
    required this.photoUrl,
    required this.timeAgo,
    required this.caption,
    required this.filterName,
  });

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  bool _showPauseIcon = false;

  void _togglePlay() {
    final c = widget.controller;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        _showPauseIcon = true;
      } else {
        c.play();
        _showPauseIcon = false;
      }
    });
    if (_showPauseIcon) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _showPauseIcon = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final filter = kVideoFilters.firstWhere(
      (f) => f.name == widget.filterName,
      orElse: () => kVideoFilters.first,
    );

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),

          // 動画プレイヤー
          if (controller != null && controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: filter.colorFilter != null
                    ? ColorFiltered(
                        colorFilter: filter.colorFilter!,
                        child: VideoPlayer(controller),
                      )
                    : VideoPlayer(controller),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white38),
            ),

          // 一時停止アイコン
          if (_showPauseIcon)
            const Center(
              child: Icon(Icons.pause_circle_filled,
                  color: Colors.white54, size: 80),
            ),

          // 下部グラデーション
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 160,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 左下: ユーザー情報
          Positioned(
            bottom: 16,
            left: 12,
            right: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    widget.photoUrl != null
                        ? CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(widget.photoUrl!),
                          )
                        : CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.red,
                            child: Text(
                              widget.username.isNotEmpty
                                  ? widget.username[0]
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.userId)
                                .snapshots(),
                            builder: (context, snap) {
                              final displayName =
                                  snap.data?.get('displayName') as String? ??
                                      widget.username;
                              return Text(displayName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis);
                            },
                          ),
                          Text(widget.timeAgo,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.caption != null &&
                    widget.caption!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.caption!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.3,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black87)
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // 右側: いいね・コメント
          Positioned(
            bottom: 20,
            right: 10,
            child: Column(
              children: [
                _SideButton(postId: widget.postId),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(
                          postId: widget.postId,
                          postData: widget.postData,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.white, size: 30,
                          shadows: const [Shadow(blurRadius: 8, color: Colors.black54)]),
                      const SizedBox(height: 6),
                      const Text('コメント',
                          style: TextStyle(color: Colors.white, fontSize: 10,
                              shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// いいねボタン
class _SideButton extends StatelessWidget {
  final String postId;
  const _SideButton({required this.postId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: LikeService.isLiked(postId),
      builder: (context, likedSnap) {
        final liked = likedSnap.data ?? false;
        return StreamBuilder<int>(
          stream: LikeService.likeCount(postId),
          builder: (context, countSnap) {
            final count = countSnap.data ?? 0;
            return GestureDetector(
              onTap: () => LikeService.toggleLike(postId),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(liked ? Icons.favorite : Icons.favorite_outline,
                      color: liked ? Colors.red : Colors.white, size: 32,
                      shadows: const [Shadow(blurRadius: 8, color: Colors.black54)]),
                  const SizedBox(height: 6),
                  Text('$count',
                      style: TextStyle(
                          color: liked ? Colors.red : Colors.white, fontSize: 11,
                          fontWeight: FontWeight.bold,
                          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)])),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
