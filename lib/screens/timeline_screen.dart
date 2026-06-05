import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../services/like_service.dart';
import '../services/shot_state.dart';
import '../utils/video_filters.dart';
import 'camera_screen.dart';
import 'post_detail_screen.dart';

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
    if (result == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shotState = context.watch<ShotState>();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            const Text('OneShot',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            if (shotState.shotTime != null && !shotState.hasPostedToday)
              _ShotTimerBadge(shotTime: shotState.shotTime!),
            if (shotState.hasPostedToday)
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
        ),
        actions: [
          if (shotState.shotTime == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () => context.read<ShotState>().startShotTimer(),
                icon: const Icon(Icons.notifications_none, color: Colors.white),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          _TikTokFeed(currentUid: currentUid, shotState: shotState),
          if (!shotState.hasPostedToday) _buildLockOverlay(),
        ],
      ),
    );
  }

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
                const Text('今日のOneShotを投稿すると、',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const Text('友達の投稿が表示されます',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _openCamera,
                  icon: const Icon(Icons.videocam, size: 22),
                  label: const Text('今すぐ撮影する',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// TikTok スタイルフィード
// ──────────────────────────────────────────────
class _TikTokFeed extends StatefulWidget {
  final String currentUid;
  final ShotState shotState;

  const _TikTokFeed({required this.currentUid, required this.shotState});

  @override
  State<_TikTokFeed> createState() => _TikTokFeedState();
}

class _TikTokFeedState extends State<_TikTokFeed> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Map<int, VideoPlayerController> _controllers = {};

  @override
  void deactivate() {
    for (final c in _controllers.values) {
      c.pause();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initController(
      int index, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (index < 0 || index >= docs.length) return;
    if (_controllers.containsKey(index)) return;

    final videoUrl = docs[index].data()['videoUrl'] as String?;
    if (videoUrl == null) return;

    final controller =
        VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _controllers[index] = controller;

    await controller.initialize();
    controller.setLooping(true);

    if (mounted && _currentPage == index) {
      controller.play();
      setState(() {});
    }
  }

  void _onPageChanged(
      int page, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    // 前のページを停止
    _controllers[_currentPage]?.pause();
    _currentPage = page;

    // 現在ページを再生
    if (_controllers.containsKey(page)) {
      _controllers[page]!.play();
    } else {
      _initController(page, docs);
    }

    // 次ページをプリロード
    _initController(page + 1, docs);

    // 古いコントローラを破棄（3ページ以上離れたもの）
    final toRemove =
        _controllers.keys.where((k) => (k - page).abs() > 2).toList();
    for (final k in toRemove) {
      _controllers[k]!.dispose();
      _controllers.remove(k);
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('follows')
          .where('followerId', isEqualTo: widget.currentUid)
          .snapshots(),
      builder: (context, followsSnap) {
        final followingIds = followsSnap.data?.docs
                .map((d) => d.data()['followingId'] as String)
                .toList() ??
            [];
        final targetIds =
            [widget.currentUid, ...followingIds].take(30).toList();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .where('userId', whereIn: targetIds)
              .snapshots(),
          builder: (context, postsSnap) {
            final now = DateTime.now();
            final twoDaysAgo = now.subtract(const Duration(days: 2));
            final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
              ...(postsSnap.data?.docs ?? [])
            ]
              ..retainWhere((d) {
                final createdAt = (d.data()['createdAt'] as Timestamp?)?.toDate();
                return createdAt != null && createdAt.isAfter(twoDaysAgo);
              })
              ..sort((a, b) {
                final aT =
                    (a.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
                final bT =
                    (b.data()['createdAt'] as Timestamp?)?.seconds ?? 0;
                return bT.compareTo(aT);
              });

            if (docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          color: Color(0xFF333333), size: 56),
                      SizedBox(height: 16),
                      Text('友達を追加すると\nここに投稿が表示されます',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 14,
                              height: 1.6)),
                    ],
                  ),
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
                final isOwn = data['userId'] == widget.currentUid;
                final createdAt =
                    (data['createdAt'] as Timestamp?)?.toDate();
                final postedAt =
                    (data['postedAt'] as Timestamp?)?.toDate() ?? createdAt;
                final isLate = data['isLate'] as bool? ?? false;
                final lateLabel =
                    isLate ? widget.shotState.lateLabel(postedAt) : '';

                return _VideoPage(
                  postId: docs[index].id,
                  postData: data,
                  userId: data['userId'] as String? ?? '',
                  controller: _controllers[index],
                  username: data['username'] ?? 'ユーザー',
                  photoUrl: data['photoUrl'] as String?,
                  timeAgo: _formatTimeAgo(createdAt),
                  locationName: data['locationName'] as String?,
                  caption: data['caption'] as String?,
                  filterName: data['filterName'] as String?,
                  isOwn: isOwn,
                  isLate: isLate,
                  lateLabel: lateLabel,
                );
              },
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

// ──────────────────────────────────────────────
// 1ページ = 1動画（全画面）
// ──────────────────────────────────────────────
class _VideoPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final String userId;
  final VideoPlayerController? controller;
  final String username;
  final String? photoUrl;
  final String timeAgo;
  final String? locationName;
  final String? caption;
  final String? filterName;
  final bool isOwn;
  final bool isLate;
  final String lateLabel;

  const _VideoPage({
    required this.postId,
    required this.postData,
    required this.userId,
    required this.controller,
    required this.username,
    required this.photoUrl,
    required this.timeAgo,
    required this.locationName,
    required this.caption,
    required this.filterName,
    required this.isOwn,
    required this.isLate,
    required this.lateLabel,
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

    return Column(
      children: [
        // 上部: 投稿者情報
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 80, 12, 12),
          child: Row(
            children: [
              widget.photoUrl != null
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(widget.photoUrl!),
                    )
                  : CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.red,
                      child: Text(
                        widget.username.isNotEmpty ? widget.username[0] : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
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
                        return Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    Row(
                      children: [
                        Text(
                          widget.timeAgo,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        if (widget.locationName != null) ...[
                          const Text(
                            ' · ',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          const Icon(Icons.location_on,
                              color: Colors.white54, size: 10),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              widget.locationName!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 中央: 動画エリア
        Expanded(
          child: GestureDetector(
            onTap: _togglePlay,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black),
                if (controller != null && controller.value.isInitialized)
                  Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: Builder(builder: (_) {
                        final f = kVideoFilters.firstWhere(
                          (f) => f.name == widget.filterName,
                          orElse: () => kVideoFilters.first,
                        );
                        return f.colorFilter != null
                            ? ColorFiltered(
                                colorFilter: f.colorFilter!,
                                child: VideoPlayer(controller),
                              )
                            : VideoPlayer(controller);
                      }),
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white38),
                  ),
                if (_showPauseIcon)
                  const Center(
                    child: Icon(Icons.pause_circle_filled,
                        color: Colors.white54, size: 80),
                  ),
                if (widget.caption != null && widget.caption!.isNotEmpty)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Text(
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
                  ),
                if (controller != null && controller.value.isInitialized)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                // 右側: リアクションボタン（縦配置）
                Positioned(
                  right: 12,
                  bottom: 80,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                            const Icon(Icons.chat_bubble_outline,
                                color: Colors.white, size: 28),
                            const SizedBox(height: 4),
                            const Text('コメント',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ReactionButton(postId: widget.postId),
                    ],
                  ),
                ),
              ],
            ),
          ),
            ),
        ),
      ],
    );
  }
}

// いいねボタン（Firestore連動・Instagramスタイル）
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

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black54)]),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    shadows: const [Shadow(blurRadius: 4, color: Colors.black54)])),
          ],
        ],
      ),
    );
  }
}

// タイマーバッジ
class _ShotTimerBadge extends StatefulWidget {
  final DateTime shotTime;
  const _ShotTimerBadge({required this.shotTime});

  @override
  State<_ShotTimerBadge> createState() => _ShotTimerBadgeState();
}

class _ShotTimerBadgeState extends State<_ShotTimerBadge> {
  late final _sub = Stream.periodic(const Duration(seconds: 1))
      .listen((_) { if (mounted) setState(() {}); });

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.shotTime);
    final remaining =
        ShotState.lateThresholdMinutes * 60 - elapsed.inSeconds;
    final isLate = remaining <= 0;
    final isUrgent = remaining > 0 && remaining < 30;

    if (isLate) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('遅刻中',
            style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      );
    }

    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final s = (remaining % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red : Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer,
              color: isUrgent ? Colors.white : Colors.white70, size: 13),
          const SizedBox(width: 4),
          Text('$m:$s',
              style: TextStyle(
                  color: isUrgent ? Colors.white : Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  final String postId;
  const _ReactionButton({required this.postId});

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with TickerProviderStateMixin {
  static const reactions = ['❤️', '😂', '😮', '😢', '🔥', '😍'];
  int _selectedReaction = 0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showReactionMenu(TapDownDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);

    showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + details.localPosition.dx,
        offset.dy + details.localPosition.dy - 200,
        0,
        0,
      ),
      items: List.generate(
        reactions.length,
        (i) => PopupMenuItem(
          value: i,
          child: Text(reactions[i], style: const TextStyle(fontSize: 24)),
        ),
      ),
    ).then((value) {
      if (value != null) {
        setState(() => _selectedReaction = value);
        _playReactionAnimation(details.globalPosition);
      }
    });
  }

  void _playReactionAnimation(Offset position) {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FloatingReaction(
        position: position,
        reaction: reactions[_selectedReaction],
        animation: controller,
        onComplete: () {
          entry.remove();
          controller.dispose();
        },
      ),
    );

    Overlay.of(context).insert(entry);
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _showReactionMenu,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_reaction_outlined,
              color: Colors.white,
              size: 30,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black54)]),
          const SizedBox(height: 6),
          const Text('リアクション',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
        ],
      ),
    );
  }
}

class _FloatingReaction extends StatefulWidget {
  final Offset position;
  final String reaction;
  final AnimationController animation;
  final VoidCallback onComplete;

  const _FloatingReaction({
    required this.position,
    required this.reaction,
    required this.animation,
    required this.onComplete,
  });

  @override
  State<_FloatingReaction> createState() => _FloatingReactionState();
}

class _FloatingReactionState extends State<_FloatingReaction> {
  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_handleAnimationStatus);
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_handleAnimationStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offsetTween = Tween<double>(begin: 0, end: -150);
    final opacityTween = Tween<double>(begin: 1, end: 0);

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        return Positioned(
          left: widget.position.dx,
          top: widget.position.dy + offsetTween.evaluate(widget.animation),
          child: Opacity(
            opacity: opacityTween.evaluate(widget.animation),
            child: Text(
              widget.reaction,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        );
      },
    );
  }
}
