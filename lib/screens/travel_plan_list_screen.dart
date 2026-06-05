import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/travel_plan.dart';
import '../services/travel_plan_service.dart';
import 'travel_plan_create_screen.dart';
import 'travel_plan_detail_screen.dart';

class TravelPlanListScreen extends StatefulWidget {
  const TravelPlanListScreen({super.key});

  @override
  State<TravelPlanListScreen> createState() => _TravelPlanListScreenState();
}

class _TravelPlanListScreenState extends State<TravelPlanListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: const Text(
          '旅行プラン',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF555555),
          tabs: const [
            Tab(text: 'マイプラン'),
            Tab(text: 'みんなのプラン'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TravelPlanCreateScreen()),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyPlansTab(),
          _PublicPlansTab(),
        ],
      ),
    );
  }
}

class _MyPlansTab extends StatelessWidget {
  const _MyPlansTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TravelPlanService.myPlansStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.map_outlined,
            message: '旅行プランがありません',
            sub: '右上の＋ボタンで作成しましょう',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final plan = TravelPlan.fromDoc(docs[i]);
            return _PlanCard(plan: plan, showDelete: true);
          },
        );
      },
    );
  }
}

class _PublicPlansTab extends StatelessWidget {
  const _PublicPlansTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: TravelPlanService.publicPlansStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.public_outlined,
            message: '公開プランがありません',
            sub: '最初の旅行プランを共有しましょう',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final plan = TravelPlan.fromDoc(docs[i]);
            return _PlanCard(plan: plan, showDelete: false);
          },
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final TravelPlan plan;
  final bool showDelete;

  const _PlanCard({required this.plan, required this.showDelete});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = uid == plan.authorId;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TravelPlanDetailScreen(plan: plan)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.purple.withOpacity(0.2),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Text('✈️', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📍 ${plan.destination}',
                          style: const TextStyle(
                            color: Color(0xFFCCCCCC),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showDelete && isOwner)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFF888888), size: 20),
                      onPressed: () => _confirmDelete(context),
                    ),
                ],
              ),
            ),

            // 詳細情報
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: _formatDate(plan.startDate),
                      ),
                      const Text(' 〜 ', style: TextStyle(color: Color(0xFF888888))),
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: _formatDate(plan.endDate),
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.nights_stay_outlined,
                        label: '${plan.durationDays}日間',
                      ),
                    ],
                  ),
                  if (plan.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        plan.description,
                        style: const TextStyle(color: Color(0xFF999999), fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!isOwner) ...[
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: plan.authorPhotoUrl != null
                              ? NetworkImage(plan.authorPhotoUrl!)
                              : null,
                          backgroundColor: const Color(0xFF2A2A2A),
                          child: plan.authorPhotoUrl == null
                              ? const Icon(Icons.person, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          plan.authorName,
                          style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: plan.isPublic
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          plan.isPublic ? '公開' : '非公開',
                          style: TextStyle(
                            color: plan.isPublic ? Colors.blue : Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.favorite_border, color: Color(0xFF888888), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${plan.likeCount}',
                        style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.month}/${d.day}';

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('削除確認', style: TextStyle(color: Colors.white)),
        content: const Text('このプランを削除しますか？', style: TextStyle(color: Color(0xFFCCCCCC))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル', style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await TravelPlanService.deletePlan(plan.id);
            },
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF888888), size: 13),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String sub;

  const _EmptyState({required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF2A2A2A), size: 56),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Color(0xFF555555), fontSize: 15)),
          const SizedBox(height: 6),
          Text(sub, style: const TextStyle(color: Color(0xFF333333), fontSize: 12)),
        ],
      ),
    );
  }
}
