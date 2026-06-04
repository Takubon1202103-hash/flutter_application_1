import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/follow_service.dart';
import 'my_qr_screen.dart';
import 'qr_scanner_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text('友達',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: Colors.white),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyQrScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF555555),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'フォロワー'),
            Tab(text: 'フォロー中'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FollowList(uid: uid, isFollowers: true),
          _FollowList(uid: uid, isFollowers: false),
        ],
      ),
    );
  }
}

class _FollowList extends StatefulWidget {
  final String uid;
  final bool isFollowers;

  const _FollowList({required this.uid, required this.isFollowers});

  @override
  State<_FollowList> createState() => _FollowListState();
}

class _FollowListState extends State<_FollowList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _query = '';

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final stream = widget.isFollowers
        ? FirebaseFirestore.instance
            .collection('follows')
            .where('followingId', isEqualTo: widget.uid)
            .snapshots()
        : FirebaseFirestore.instance
            .collection('follows')
            .where('followerId', isEqualTo: widget.uid)
            .snapshots();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ユーザー名で検索',
              hintStyle: const TextStyle(color: Color(0xFF555555)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF555555)),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline,
                          color: Color(0xFF333333), size: 56),
                      const SizedBox(height: 16),
                      Text(
                        widget.isFollowers
                            ? 'まだフォロワーがいません'
                            : 'まだフォローしていません',
                        style: const TextStyle(
                            color: Color(0xFF666666), fontSize: 14),
                      ),
                      if (!widget.isFollowers) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'QRコードで友達を追加しよう',
                          style: TextStyle(
                              color: Color(0xFF444444), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                );
              }

              final userIds = docs.map((d) {
                return widget.isFollowers
                    ? d.data()['followerId'] as String
                    : d.data()['followingId'] as String;
              }).toList();

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: userIds.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Color(0xFF1E1E1E), height: 1),
                itemBuilder: (context, index) =>
                    _UserTile(uid: userIds[index], query: _query),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  final String uid;
  final String query;

  const _UserTile({required this.uid, required this.query});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(
            leading: CircleAvatar(backgroundColor: Color(0xFF1A1A1A)),
            title: Text('...', style: TextStyle(color: Colors.white)),
          );
        }

        final data = snapshot.data!.data() ?? {};
        final name = data['displayName'] as String? ?? 'ユーザー';
        final photoUrl = data['photoUrl'] as String?;

        // 検索フィルター
        if (query.isNotEmpty && !name.toLowerCase().contains(query)) {
          return const SizedBox.shrink();
        }

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            radius: 24,
            backgroundImage:
                photoUrl != null ? NetworkImage(photoUrl) : null,
            backgroundColor: Colors.red,
            child: photoUrl == null
                ? Text(name[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold))
                : null,
          ),
          title: Text(name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          trailing: _FollowButton(targetUid: uid),
        );
      },
    );
  }
}

class _FollowButton extends StatelessWidget {
  final String targetUid;
  const _FollowButton({required this.targetUid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: FollowService.isFollowing(targetUid),
      builder: (context, snapshot) {
        final following = snapshot.data ?? false;
        return GestureDetector(
          onTap: () async {
            if (following) {
              await FollowService.unfollow(targetUid);
            } else {
              await FollowService.follow(targetUid);
            }
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: following ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              following ? 'フォロー中' : 'フォロー',
              style: TextStyle(
                color: following ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
  }
}
