import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../services/like_service.dart';
import '../utils/video_filters.dart';
import 'post_detail_screen.dart';

class VideoHistoryScreen extends StatefulWidget {
  const VideoHistoryScreen({super.key});

  @override
  State<VideoHistoryScreen> createState() => _VideoHistoryScreenState();
}

class _VideoHistoryScreenState extends State<VideoHistoryScreen> {
  final Map<int, VideoPlayerController?> _controllers = {};

  @override
  void dispose() {
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
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snap) {
          var docs = snap.data?.docs ?? [];

          // createdAt で降順ソート
          docs.sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
            final bTime = (b.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'まだ動画がありません',
                style: TextStyle(color: Color(0xFF555555), fontSize: 14),
              ),
            );
          }

          return Scrollbar(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final videoUrl = data['videoUrl'] as String?;
                final thumbnailUrl = data['thumbnailUrl'] as String?;

                if (videoUrl == null) {
                  return const SizedBox();
                }

                return _VideoThumbnail(
                  postId: docs[index].id,
                  postData: data,
                  videoUrl: videoUrl,
                  thumbnailUrl: thumbnailUrl,
                  username: data['username'] ?? 'ユーザー',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _VideoDetailScreen(
                          postId: docs[index].id,
                          postData: data,
                          userId: data['userId'] as String? ?? '',
                          username: data['username'] ?? 'ユーザー',
                          photoUrl: data['photoUrl'] as String?,
                          caption: data['caption'] as String?,
                          filterName: data['filterName'] as String?,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final String userId;
  final VideoPlayerController? controller;
  final String username;
  final String? photoUrl;
  final String? caption;
  final String? filterName;

  const _VideoPage({
    required this.postId,
    required this.postData,
    required this.userId,
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

  void _showContextMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: const Color(0xFF1A1A1A),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _ContextMenuItem(
              icon: Icons.download_outlined,
              label: 'ダウンロード',
              onTap: () {
                Navigator.pop(context);
                _downloadVideo();
              },
            ),
            _ContextMenuItem(
              icon: Icons.share_outlined,
              label: '共有',
              onTap: () {
                Navigator.pop(context);
                _shareVideo();
              },
            ),
            _ContextMenuItem(
              icon: Icons.delete_outlined,
              label: '削除',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deleteVideo();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadVideo() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ダウンロード機能は準備中です')),
    );
  }

  Future<void> _shareVideo() async {
    final videoUrl = widget.postData['videoUrl'] as String?;
    if (videoUrl == null) return;

    await Share.share(
      '${widget.username}の動画を見てください！\n$videoUrl',
      subject: 'OneShot 動画シェア',
    );
  }

  Future<void> _deleteVideo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          '削除確認',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'この動画を削除しますか？',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final videoUrl = widget.postData['videoUrl'] as String?;
      final thumbnailUrl = widget.postData['thumbnailUrl'] as String?;

      // Firebase Storage から削除
      if (videoUrl != null) {
        await FirebaseStorage.instance.refFromURL(videoUrl).delete();
      }
      if (thumbnailUrl != null) {
        await FirebaseStorage.instance.refFromURL(thumbnailUrl).delete();
      }

      // Firestore から削除
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('動画を削除しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
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
      onLongPress: _showContextMenu,
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

class _VideoThumbnail extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final String videoUrl;
  final String? thumbnailUrl;
  final String username;
  final VoidCallback onTap;

  const _VideoThumbnail({
    required this.postId,
    required this.postData,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.username,
    required this.onTap,
  });

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  late Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _generateThumbnail();
  }

  Future<Uint8List?> _generateThumbnail() async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.PNG,
        maxHeight: 150,
        quality: 75,
      );
      return uint8list;
    } catch (e) {
      return null;
    }
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: const Color(0xFF1A1A1A),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _ContextMenuItem(
              icon: Icons.download_outlined,
              label: 'ダウンロード',
              onTap: () => Navigator.pop(context),
            ),
            _ContextMenuItem(
              icon: Icons.share_outlined,
              label: '共有',
              onTap: () {
                Navigator.pop(context);
                Share.share('${widget.username} の動画を見てください！\n${widget.videoUrl}');
              },
            ),
            _ContextMenuItem(
              icon: Icons.delete_outlined,
              label: '削除',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _deleteVideo(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteVideo(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          '削除確認',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'この動画を削除しますか？',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (widget.thumbnailUrl != null) {
        await FirebaseStorage.instance.refFromURL(widget.thumbnailUrl!).delete();
      }
      await FirebaseStorage.instance.refFromURL(widget.videoUrl).delete();
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('動画を削除しました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: () => _showContextMenu(context),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // サムネイル（動画から自動生成）
            FutureBuilder<Uint8List?>(
              future: _thumbnailFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                    ),
                  );
                } else if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white30),
                        ),
                      ),
                    ),
                  );
                } else {
                  return Container(
                    color: Colors.black,
                    child: const Icon(
                      Icons.videocam_outlined,
                      color: Colors.white30,
                      size: 32,
                    ),
                  );
                }
              },
            ),
            // 再生アイコン
            const Center(
              child: Icon(
                Icons.play_circle_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

class _VideoDetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final String userId;
  final String username;
  final String? photoUrl;
  final String? caption;
  final String? filterName;

  const _VideoDetailScreen({
    required this.postId,
    required this.postData,
    required this.userId,
    required this.username,
    required this.photoUrl,
    required this.caption,
    required this.filterName,
  });

  @override
  State<_VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<_VideoDetailScreen> {
  late VideoPlayerController _controller;
  bool _showPauseIcon = false;

  @override
  void initState() {
    super.initState();
    final videoUrl = widget.postData['videoUrl'] as String?;
    if (videoUrl != null) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) {
            _controller.play();
            setState(() {});
          }
        });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _showPauseIcon = true;
      } else {
        _controller.play();
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: GestureDetector(
          onTap: _togglePlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller.value.isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white38),
                ),
              if (_showPauseIcon)
                const Center(
                  child: Icon(
                    Icons.pause_circle_filled,
                    color: Colors.white54,
                    size: 80,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
