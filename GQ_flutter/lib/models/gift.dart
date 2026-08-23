import 'package:cloud_firestore/cloud_firestore.dart';

/// Matches `users/{uid}/items/{itemId}` in Firestore.
/// Renamed from Kotlin's `Item` to `Gift` for clarity in the Dart codebase —
/// the Firestore collection path itself (`items`) is unchanged for compatibility.
class Gift {
  final String id;
  final String title;
  final String category;
  final double price;
  final String link;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double position;
  final String? photoUrl;

  const Gift({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    required this.link,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.position,
    this.photoUrl,
  });

  factory Gift.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Gift(
      id: doc.id,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      link: data['link'] as String? ?? '',
      note: data['note'] as String? ?? '',
      createdAt: _parseTimestamp(data['createdAtMillis'] ?? data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAtMillis'] ?? data['updatedAt']),
      position: (data['position'] as num?)?.toDouble() ?? 0.0,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  /// Writes new records using Firestore's native Timestamp type going forward.
  /// Old records written by the Kotlin app (with createdAtMillis/updatedAtMillis
  /// as raw ints) are still readable via `_parseTimestamp` above.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'category': category,
      'price': price,
      'link': link,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'position': position,
      'photoUrl': photoUrl,
    };
  }

  Gift copyWith({
    String? title,
    String? category,
    double? price,
    String? link,
    String? note,
    double? position,
    String? photoUrl,
  }) {
    return Gift(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      price: price ?? this.price,
      link: link ?? this.link,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      position: position ?? this.position,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

/// Handles both the new Firestore Timestamp type and the old raw millis
/// (int) values written by the Kotlin app, so existing data keeps working.
DateTime _parseTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.now();
}
