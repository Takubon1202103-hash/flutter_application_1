import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../services/like_service.dart';
import '../utils/video_filters.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.postData,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  VideoPlayerController? _videoController;
  final _commentController = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    final videoUrl = widget.postData['videoUrl'] as String?;
    if (videoUrl != null) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(videoUrl))
            ..initialize().then((_) {
              if (mounted) {
                setState(() {});
                _videoController!.setLooping(true);
                _videoController!.play();
              }
            });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _posting = true);
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'userId': user.uid,
      'username': user.displayName ?? 'ユーザー',
      'photoUrl': user.photoURL,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _commentController.clear();
    setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) {
    final filterName = widget.postData['filterName'] as String?;
    final caption = widget.postData['caption'] as String?;
    final username = widget.postData['username'] as String? ?? 'ユーザー';
    final photoUrl = widget.postData['photoUrl'] as String?;
    final filter = kVideoFilters.firstWhere(
      (f) => f.name == filterName,
      orElse: () => kVideoFilters.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            photoUrl != null
                ? CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(photoUrl),
                  )
                : CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.red,
                    child: Text(username[0],
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
            const SizedBox(width: 10),
            Text(username,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 動画プレイヤー
          AspectRatio(
            aspectRatio: _videoController?.value.isInitialized == true
                ? _videoController!.value.aspectRatio
                : 9 / 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (_videoController?.value.isPlaying == true) {
                    _videoController?.pause();
                  } else {
                    _videoController?.play();
                  }
                });
              },
              child: _videoController?.value.isInitialized == true
                  ? filter.colorFilter != null
                      ? ColorFiltered(
                          colorFilter: filter.colorFilter!,
                          child: VideoPlayer(_videoController!),
                        )
                      : VideoPlayer(_videoController!)
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
            ),
          ),

          // いいね・コメント数
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                // いいね
                StreamBuilder<bool>(
                  stream: LikeService.isLiked(widget.postId),
                  builder: (context, snap) {
                    final liked = snap.data ?? false;
                    return StreamBuilder<int>(
                      stream: LikeService.likeCount(widget.postId),
                      builder: (context, countSnap) {
                        final count = countSnap.data ?? 0;
                        return GestureDetector(
                          onTap: () => LikeService.toggleLike(widget.postId),
                          child: Row(
                            children: [
                              Icon(
                                liked ? Icons.favorite : Icons.favorite_border,
                                color: liked ? Colors.red : Colors.white70,
                                size: 24,
                              ),
                              const SizedBox(width: 6),
                              Text('$count',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(width: 20),
                // コメント数
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.postId)
                      .collection('comments')
                      .snapshots(),
                  builder: (context, snap) {
                    final count = snap.data?.docs.length ?? 0;
                    return Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            color: Colors.white70, size: 22),
                        const SizedBox(width: 6),
                        Text('$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // キャプション
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(caption,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4)),
              ),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFF1E1E1E), height: 1),
          ),

          // コメント一覧
          SizedBox(
            height: 300,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .snapshots(),
              builder: (context, snap) {
                final docs = [...(snap.data?.docs ?? [])]
                  ..sort((a, b) {
                    final aT =
                        (a.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
                    final bT =
                        (b.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
                    return aT.compareTo(bT);
                  });

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('まだコメントがありません',
                        style: TextStyle(color: Color(0xFF555555))),
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final d = docs[index].data();
                    final name = d['username'] as String? ?? 'ユーザー';
                    final photo = d['photoUrl'] as String?;
                    final text = d['text'] as String? ?? '';
                    final ts = (d['createdAt'] as Timestamp?)?.toDate();
                    final timeAgo = _formatTimeAgo(ts);

                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            photo != null ? NetworkImage(photo) : null,
                        backgroundColor: Colors.red,
                        child: photo == null
                            ? Text(name[0],
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))
                            : null,
                      ),
                      title: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$name  ',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            TextSpan(
                              text: text,
                              style: const TextStyle(
                                  color: Color(0xFFCCCCCC), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      subtitle: Text(timeAgo,
                          style: const TextStyle(
                              color: Color(0xFF555555), fontSize: 11)),
                    );
                  },
                );
              },
            ),
          ),

          // コメント入力
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'コメントを追加...',
                        hintStyle: const TextStyle(color: Color(0xFF555555)),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _posting ? null : _postComment,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: _posting
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
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
