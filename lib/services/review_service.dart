import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/review.dart';

class ReviewService {
  ReviewService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : _firestore =
            firestore ?? FirebaseFirestore.instance,
        _firebaseAuth =
            firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>>
      get _reviews {
    return _firestore.collection('reviews');
  }

  User _requireCurrentUser() {
    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'You must be logged in to perform this action.',
      );
    }

    return user;
  }

  Future<String> createReview({
    required String bookId,
    required int rating,
    required String text,
  }) async {
    final User user = _requireCurrentUser();

    final String normalizedBookId =
        bookId.trim();

    final String normalizedText = text.trim();

    _validateReview(
      bookId: normalizedBookId,
      rating: rating,
      text: normalizedText,
    );

    final Review? existingReview =
        await getCurrentUserReviewForBook(
      normalizedBookId,
    );

    if (existingReview != null) {
      throw StateError(
        'You have already reviewed this book.',
      );
    }

    final DocumentReference<Map<String, dynamic>>
        document = await _reviews.add(
      <String, dynamic>{
        'userId': user.uid,
        'bookId': normalizedBookId,
        'rating': rating,
        'text': normalizedText,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    return document.id;
  }

  Future<void> updateReview({
    required String reviewId,
    required int rating,
    required String text,
  }) async {
    final User user = _requireCurrentUser();

    final String normalizedReviewId =
        reviewId.trim();

    final String normalizedText = text.trim();

    if (normalizedReviewId.isEmpty) {
      throw ArgumentError(
        'The review ID cannot be empty.',
      );
    }

    _validateReview(
      bookId: 'existing-book',
      rating: rating,
      text: normalizedText,
    );

    final DocumentReference<Map<String, dynamic>>
        reference = _reviews.doc(
      normalizedReviewId,
    );

    final DocumentSnapshot<Map<String, dynamic>>
        snapshot = await reference.get();

    if (!snapshot.exists) {
      throw StateError(
        'The review does not exist.',
      );
    }

    final Map<String, dynamic> data =
        snapshot.data() ?? <String, dynamic>{};

    if (data['userId'] != user.uid) {
      throw StateError(
        'You can edit only your own reviews.',
      );
    }

    await reference.update(
      <String, dynamic>{
        'rating': rating,
        'text': normalizedText,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteReview(
    String reviewId,
  ) async {
    final User user = _requireCurrentUser();

    final DocumentReference<Map<String, dynamic>>
        reference = _reviews.doc(
      reviewId.trim(),
    );

    final DocumentSnapshot<Map<String, dynamic>>
        snapshot = await reference.get();

    if (!snapshot.exists) {
      return;
    }

    final Map<String, dynamic> data =
        snapshot.data() ?? <String, dynamic>{};

    if (data['userId'] != user.uid) {
      throw StateError(
        'You can delete only your own reviews.',
      );
    }

    await reference.delete();
  }

  Future<Review?> getReviewById(
    String reviewId,
  ) async {
    final DocumentSnapshot<Map<String, dynamic>>
        snapshot = await _reviews
            .doc(reviewId.trim())
            .get();

    if (!snapshot.exists) {
      return null;
    }

    return Review.fromFirestore(snapshot);
  }

  Future<Review?> getCurrentUserReviewForBook(
    String bookId,
  ) async {
    final User user = _requireCurrentUser();

    final QuerySnapshot<Map<String, dynamic>>
        snapshot = await _reviews
            .where(
              'userId',
              isEqualTo: user.uid,
            )
            .get();

    for (final QueryDocumentSnapshot<
        Map<String, dynamic>> document
        in snapshot.docs) {
      if (document.data()['bookId'] == bookId) {
        return Review.fromFirestore(document);
      }
    }

    return null;
  }

  Future<List<Review>> getReviewsForBook(
    String bookId,
  ) async {
    final QuerySnapshot<Map<String, dynamic>>
        snapshot = await _reviews
            .where(
              'bookId',
              isEqualTo: bookId.trim(),
            )
            .get();

    final List<Review> reviews = snapshot.docs
        .map(Review.fromFirestore)
        .toList();

    reviews.sort(
      (Review first, Review second) {
        final DateTime firstDate =
            first.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

        final DateTime secondDate =
            second.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

        return secondDate.compareTo(firstDate);
      },
    );

    return reviews;
  }

  Future<List<Review>>
      getCurrentUserReviews() async {
    final User user = _requireCurrentUser();

    final QuerySnapshot<Map<String, dynamic>>
        snapshot = await _reviews
            .where(
              'userId',
              isEqualTo: user.uid,
            )
            .get();

    final List<Review> reviews = snapshot.docs
        .map(Review.fromFirestore)
        .toList();

    reviews.sort(
      (Review first, Review second) {
        final DateTime firstDate =
            first.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

        final DateTime secondDate =
            second.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0);

        return secondDate.compareTo(firstDate);
      },
    );

    return reviews;
  }

  Future<int> getCurrentUserReviewCount() async {
    final List<Review> reviews =
        await getCurrentUserReviews();

    return reviews.length;
  }

  Stream<List<Review>> watchReviewsForBook(
    String bookId,
  ) {
    return _reviews
        .where(
          'bookId',
          isEqualTo: bookId.trim(),
        )
        .snapshots()
        .map(
      (
        QuerySnapshot<Map<String, dynamic>>
            snapshot,
      ) {
        final List<Review> reviews = snapshot.docs
            .map(Review.fromFirestore)
            .toList();

        reviews.sort(
          (Review first, Review second) {
            final DateTime firstDate =
                first.createdAt ??
                    DateTime
                        .fromMillisecondsSinceEpoch(0);

            final DateTime secondDate =
                second.createdAt ??
                    DateTime
                        .fromMillisecondsSinceEpoch(0);

            return secondDate.compareTo(
              firstDate,
            );
          },
        );

        return reviews;
      },
    );
  }

  void _validateReview({
    required String bookId,
    required int rating,
    required String text,
  }) {
    if (bookId.isEmpty) {
      throw ArgumentError(
        'The book ID cannot be empty.',
      );
    }

    if (rating < 1 || rating > 5) {
      throw ArgumentError(
        'The rating must be between 1 and 5.',
      );
    }

    if (text.isEmpty) {
      throw ArgumentError(
        'The review text cannot be empty.',
      );
    }

    if (text.length > 2000) {
      throw ArgumentError(
        'The review cannot be longer than 2000 characters.',
      );
    }
  }
}