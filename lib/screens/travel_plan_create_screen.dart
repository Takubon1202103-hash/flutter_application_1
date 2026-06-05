import 'package:flutter/material.dart';
import '../models/travel_plan.dart';
import '../services/travel_plan_service.dart';
import 'travel_plan_detail_screen.dart';

class TravelPlanCreateScreen extends StatefulWidget {
  const TravelPlanCreateScreen({super.key});

  @override
  State<TravelPlanCreateScreen> createState() => _TravelPlanCreateScreenState();
}

class _TravelPlanCreateScreenState extends State<TravelPlanCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  bool _isPublic = true;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _destinationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.blue),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_startDate.isAfter(_endDate)) _startDate = _endDate;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final planId = await TravelPlanService.createPlan(
        title: _titleCtrl.text.trim(),
        destination: _destinationCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        description: _descCtrl.text.trim(),
        isPublic: _isPublic,
      );
      if (!mounted) return;

      // 作成後に詳細画面へ遷移
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TravelPlanDetailScreen(
            plan: TravelPlan(
              id: planId,
              title: _titleCtrl.text.trim(),
              destination: _destinationCtrl.text.trim(),
              startDate: _startDate,
              endDate: _endDate,
              description: _descCtrl.text.trim(),
              isPublic: _isPublic,
              likeCount: 0,
              authorId: '',
              authorName: '',
              createdAt: DateTime.now(),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '旅行プランを作成',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                  )
                : const Text('作成', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionLabel('基本情報'),
            const SizedBox(height: 12),
            _DarkTextField(
              controller: _titleCtrl,
              label: '旅行タイトル',
              hint: '例: 京都・大阪の旅',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'タイトルを入力してください' : null,
            ),
            const SizedBox(height: 12),
            _DarkTextField(
              controller: _destinationCtrl,
              label: '目的地',
              hint: '例: 京都、大阪',
              validator: (v) => (v == null || v.trim().isEmpty) ? '目的地を入力してください' : null,
            ),
            const SizedBox(height: 24),
            _SectionLabel('旅行期間'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateSelector(
                    label: '出発日',
                    date: _startDate,
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('〜', style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
                Expanded(
                  child: _DateSelector(
                    label: '帰着日',
                    date: _endDate,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${_endDate.difference(_startDate).inDays + 1}日間の旅行',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel('説明'),
            const SizedBox(height: 12),
            _DarkTextField(
              controller: _descCtrl,
              label: 'プランの説明（任意）',
              hint: '旅行のテーマやコンセプトを書いてみましょう',
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            _SectionLabel('公開設定'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: SwitchListTile(
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                title: Text(
                  _isPublic ? '公開' : '非公開',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _isPublic ? 'みんなのプランに表示されます' : '自分だけに表示されます',
                  style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                ),
                activeColor: Colors.blue,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF888888),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final String? Function(String?)? validator;

  const _DarkTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFF888888)),
        hintStyle: const TextStyle(color: Color(0xFF444444)),
        filled: true,
        fillColor: const Color(0xFF151515),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateSelector({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
