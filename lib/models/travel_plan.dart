import 'package:cloud_firestore/cloud_firestore.dart';

class TravelSpot {
  final String id;
  final String name;
  final String category;
  final DateTime? visitDate;
  final String memo;
  final int order;

  TravelSpot({
    required this.id,
    required this.name,
    required this.category,
    this.visitDate,
    required this.memo,
    required this.order,
  });

  factory TravelSpot.fromMap(String id, Map<String, dynamic> map) {
    return TravelSpot(
      id: id,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'other',
      visitDate: (map['visitDate'] as Timestamp?)?.toDate(),
      memo: map['memo'] as String? ?? '',
      order: map['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'visitDate': visitDate != null ? Timestamp.fromDate(visitDate!) : null,
    'memo': memo,
    'order': order,
  };

  static String categoryLabel(String cat) {
    switch (cat) {
      case 'food': return 'グルメ';
      case 'sight': return '観光';
      case 'hotel': return '宿泊';
      case 'transport': return '交通';
      default: return 'その他';
    }
  }

  static String categoryIcon(String cat) {
    switch (cat) {
      case 'food': return '🍽️';
      case 'sight': return '📸';
      case 'hotel': return '🏨';
      case 'transport': return '🚆';
      default: return '📍';
    }
  }
}

class TravelPlan {
  final String id;
  final String title;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String description;
  final String? coverImageUrl;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final bool isPublic;
  final int likeCount;
  final DateTime createdAt;

  TravelPlan({
    required this.id,
    required this.title,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.description,
    this.coverImageUrl,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.isPublic,
    required this.likeCount,
    required this.createdAt,
  });

  factory TravelPlan.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return TravelPlan(
      id: doc.id,
      title: d['title'] as String? ?? '',
      destination: d['destination'] as String? ?? '',
      startDate: (d['startDate'] as Timestamp).toDate(),
      endDate: (d['endDate'] as Timestamp).toDate(),
      description: d['description'] as String? ?? '',
      coverImageUrl: d['coverImageUrl'] as String?,
      authorId: d['authorId'] as String? ?? '',
      authorName: d['authorName'] as String? ?? 'ユーザー',
      authorPhotoUrl: d['authorPhotoUrl'] as String?,
      isPublic: d['isPublic'] as bool? ?? true,
      likeCount: d['likeCount'] as int? ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  int get durationDays => endDate.difference(startDate).inDays + 1;
}
