import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/like_service.dart';
import '../utils/video_filters.dart';
import 'post_detail_screen.dart';

class VideoHistoryScreen extends StatefulWidget {
  const VideoHistoryScreen({super.key});

  @override
  State<VideoHistoryScreen> createState() => _VideoHistoryScreenState();
}

class _VideoHistoryScreenState extends State<VideoHistoryScreen> {
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
          '撮影した動画',
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
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'まだ動画がありません',
                style: TextStyle(color: Color(0xFF555555), fontSize: 14),
              ),
            );
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final videoUrl = data['videoUrl'] as String?;

              if (videoUrl == null) {
                return const SizedBox();
              }

              if (!_controllers.containsKey(index)) {
                _controllers[index] = VideoPlayerController.networkUrl(
                  Uri.parse(videoUrl),
                )..initialize().then((_) {
                    if (mounted) setState(() {});
                  });
              }

              return _VideoPage(
                postId: docs[index].id,
                postData: data,
                controller: _controllers[index],
                username: data['username'] ?? 'ユーザー',
                photoUrl: data['photoUrl'] as String?,
                caption: data['caption'] as String?,
                filterName: data['filterName'] as String?,
              );
            },
          );
        },
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final VideoPlayerController? controller;
  final String username;
  final String? photoUrl;
  final String? caption;
  final String? filterName;

  const _VideoPage({
    required this.postId,
    required this.postData,
    required this.controller,
    required this.username,
    required this.photoUrl,
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
                          Text(widget.username,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
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
