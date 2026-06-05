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
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.6,
              ),
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final videoUrl = data['videoUrl'] as String?;
                final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                if (videoUrl == null) {
                  return const SizedBox();
                }

                return _VideoThumbnail(
                  postId: docs[index].id,
                  postData: data,
                  videoUrl: videoUrl,
                  username: data['username'] ?? 'ユーザー',
                  createdAt: createdAt,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _VideoDetailScreen(
                          postData: data,
                          username: data['username'] ?? 'ユーザー',
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

class _VideoThumbnail extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final String videoUrl;
  final String username;
  final DateTime? createdAt;
  final VoidCallback onTap;

  const _VideoThumbnail({
    required this.postId,
    required this.postData,
    required this.videoUrl,
    required this.username,
    required this.createdAt,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
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
          ),
          const SizedBox(height: 8),
          // 日付とユーザー名
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.createdAt != null)
                  Text(
                    '${widget.createdAt!.year}年${widget.createdAt!.month}月${widget.createdAt!.day}日',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  widget.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoDetailScreen extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String username;

  const _VideoDetailScreen({
    required this.postData,
    required this.username,
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
