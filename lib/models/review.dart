import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  const Review({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.rating,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String bookId;
  final int rating;
  final String text;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Review.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    final Object? ratingValue = data['rating'];

    return Review(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      bookId: data['bookId'] as String? ?? '',
      rating: ratingValue is num
          ? ratingValue.toInt()
          : 0,
      text: data['text'] as String? ?? '',
      createdAt: _timestampToDateTime(
        data['createdAt'],
      ),
      updatedAt: _timestampToDateTime(
        data['updatedAt'],
      ),
    );
  }

  static DateTime? _timestampToDateTime(
    Object? value,
  ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }
}