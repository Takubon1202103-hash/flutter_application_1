import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/travel_plan.dart';
import '../services/travel_plan_service.dart';

class TravelPlanDetailScreen extends StatefulWidget {
  final TravelPlan plan;
  const TravelPlanDetailScreen({super.key, required this.plan});

  @override
  State<TravelPlanDetailScreen> createState() => _TravelPlanDetailScreenState();
}

class _TravelPlanDetailScreenState extends State<TravelPlanDetailScreen> {
  late TravelPlan _plan;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
  }

  void _sharePlan() {
    final text = '【旅行プラン】${_plan.title}\n'
        '📍 ${_plan.destination}\n'
        '📅 ${_formatDate(_plan.startDate)} 〜 ${_formatDate(_plan.endDate)} (${_plan.durationDays}日間)\n'
        '${_plan.description.isNotEmpty ? '\n${_plan.description}' : ''}';
    Share.share(text);
  }

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = uid == _plan.authorId;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0A),
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: _sharePlan,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A237E), Color(0xFF4A148C)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      const Text('✈️', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text(
                        _plan.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${_plan.destination}',
                        style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 概要カード
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151515),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _StatBox(
                              icon: Icons.calendar_today_outlined,
                              label: '出発',
                              value: '${_plan.startDate.month}/${_plan.startDate.day}',
                            ),
                            _divider(),
                            _StatBox(
                              icon: Icons.flight_land_outlined,
                              label: '帰着',
                              value: '${_plan.endDate.month}/${_plan.endDate.day}',
                            ),
                            _divider(),
                            _StatBox(
                              icon: Icons.nights_stay_outlined,
                              label: '期間',
                              value: '${_plan.durationDays}日',
                            ),
                            _divider(),
                            _LikeButton(planId: _plan.id),
                          ],
                        ),
                        if (_plan.description.isNotEmpty) ...[
                          const Divider(color: Color(0xFF2A2A2A), height: 24),
                          Text(
                            _plan.description,
                            style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // スポットセクション
                  Row(
                    children: [
                      const Text(
                        '訪問スポット',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (isOwner)
                        TextButton.icon(
                          onPressed: () => _showAddSpotSheet(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('追加'),
                          style: TextButton.styleFrom(foregroundColor: Colors.blue),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // スポット一覧
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: TravelPlanService.spotsStream(_plan.id),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        const Icon(Icons.location_off_outlined, color: Color(0xFF2A2A2A), size: 48),
                        const SizedBox(height: 12),
                        const Text('スポットがありません', style: TextStyle(color: Color(0xFF555555))),
                        if (isOwner) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _showAddSpotSheet(context),
                            child: const Text('スポットを追加'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final spot = TravelSpot.fromMap(docs[i].id, docs[i].data());
                    return _SpotTile(
                      spot: spot,
                      planId: _plan.id,
                      isOwner: isOwner,
                      isLast: i == docs.length - 1,
                    );
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 40,
    color: const Color(0xFF2A2A2A),
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );

  void _showAddSpotSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddSpotSheet(planId: _plan.id),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatBox({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF888888), size: 18),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final String planId;
  const _LikeButton({required this.planId});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<bool>(
        stream: TravelPlanService.isLikedStream(planId),
        builder: (context, snap) {
          final liked = snap.data ?? false;
          return GestureDetector(
            onTap: () => TravelPlanService.toggleLike(planId),
            child: Column(
              children: [
                Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? Colors.red : const Color(0xFF888888),
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  liked ? 'いいね済' : 'いいね',
                  style: TextStyle(color: liked ? Colors.red : const Color(0xFF888888), fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SpotTile extends StatelessWidget {
  final TravelSpot spot;
  final String planId;
  final bool isOwner;
  final bool isLast;

  const _SpotTile({
    required this.spot,
    required this.planId,
    required this.isOwner,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイムライン線
            Column(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _categoryColor(spot.category).withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: _categoryColor(spot.category), width: 1.5),
                  ),
                  child: Center(
                    child: Text(TravelSpot.categoryIcon(spot.category), style: const TextStyle(fontSize: 16)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1.5, color: const Color(0xFF2A2A2A)),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // スポット情報
            Expanded(
              child: Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            spot.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isOwner)
                          GestureDetector(
                            onTap: () => TravelPlanService.deleteSpot(planId, spot.id),
                            child: const Icon(Icons.close, color: Color(0xFF555555), size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _categoryColor(spot.category).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        TravelSpot.categoryLabel(spot.category),
                        style: TextStyle(color: _categoryColor(spot.category), fontSize: 11),
                      ),
                    ),
                    if (spot.visitDate != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule, color: Color(0xFF888888), size: 13),
                          const SizedBox(width: 4),
                          Text(
                            '${spot.visitDate!.month}/${spot.visitDate!.day} '
                            '${spot.visitDate!.hour.toString().padLeft(2, '0')}:'
                            '${spot.visitDate!.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    if (spot.memo.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        spot.memo,
                        style: const TextStyle(color: Color(0xFF999999), fontSize: 13, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'food': return Colors.orange;
      case 'sight': return Colors.blue;
      case 'hotel': return Colors.purple;
      case 'transport': return Colors.green;
      default: return Colors.grey;
    }
  }
}

class _AddSpotSheet extends StatefulWidget {
  final String planId;
  const _AddSpotSheet({required this.planId});

  @override
  State<_AddSpotSheet> createState() => _AddSpotSheetState();
}

class _AddSpotSheetState extends State<_AddSpotSheet> {
  final _nameCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  String _category = 'sight';
  DateTime? _visitDate;
  bool _saving = false;

  final _categories = ['sight', 'food', 'hotel', 'transport', 'other'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    // 既存スポット数を取得してorder付与
    final snap = await FirebaseFirestore.instance
        .collection('travel_plans')
        .doc(widget.planId)
        .collection('spots')
        .get();

    final spot = TravelSpot(
      id: '',
      name: _nameCtrl.text.trim(),
      category: _category,
      visitDate: _visitDate,
      memo: _memoCtrl.text.trim(),
      order: snap.docs.length,
    );

    await TravelPlanService.addSpot(widget.planId, spot);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('スポットを追加', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue))
                    : const Text('追加', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDeco('スポット名（必須）'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          // カテゴリ選択
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((c) {
                final selected = _category == c;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? Colors.blue.withOpacity(0.3) : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? Colors.blue : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      '${TravelSpot.categoryIcon(c)} ${TravelSpot.categoryLabel(c)}',
                      style: TextStyle(
                        color: selected ? Colors.blue : const Color(0xFF888888),
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoCtrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: _inputDeco('メモ（任意）'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF555555)),
    filled: true,
    fillColor: const Color(0xFF2A2A2A),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
  );
}
