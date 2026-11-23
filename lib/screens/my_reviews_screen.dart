import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/review_card.dart';
import 'review_details_screen.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  List<_ReviewListItem> _ownReviews = <_ReviewListItem>[];
  List<_ReviewListItem> _commentedReviews = <_ReviewListItem>[];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> ownReviewSnapshot =
          await _firestore
              .collection('reviews')
              .where('userId', isEqualTo: user.uid)
              .get();

      final QuerySnapshot<Map<String, dynamic>> commentSnapshot =
          await _firestore
              .collection('review_comments')
              .where('userId', isEqualTo: user.uid)
              .get();

      final List<_ReviewListItem> ownReviews =
          await _buildReviewItems(ownReviewSnapshot.docs);

      final Set<String> ownReviewIds =
          ownReviewSnapshot.docs.map((document) => document.id).toSet();

      final Set<String> commentedReviewIds = commentSnapshot.docs
          .map(
            (document) =>
                (document.data()['reviewId'] as String? ?? '').trim(),
          )
          .where(
            (reviewId) =>
                reviewId.isNotEmpty && !ownReviewIds.contains(reviewId),
          )
          .toSet();

      final List<DocumentSnapshot<Map<String, dynamic>>>
          commentedReviewDocuments = await Future.wait(
        commentedReviewIds.map(
          (reviewId) =>
              _firestore.collection('reviews').doc(reviewId).get(),
        ),
      );

      final List<_ReviewListItem> commentedReviews =
          await _buildReviewItemsFromDocuments(
        commentedReviewDocuments.where(
          (document) => document.exists && document.data() != null,
        ),
      );

      ownReviews.sort(_compareNewestFirst);
      commentedReviews.sort(_compareNewestFirst);

      if (!mounted) {
        return;
      }

      setState(() {
        _ownReviews = ownReviews;
        _commentedReviews = commentedReviews;
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      _showMessage(error.message ?? 'Unable to load your reviews.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      _showMessage(
        'An unexpected error occurred while loading your reviews.',
      );
    }
  }

  Future<List<_ReviewListItem>> _buildReviewItems(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return Future.wait(
      documents.map(
        (document) => _buildReviewItem(document.id, document.data()),
      ),
    );
  }

  Future<List<_ReviewListItem>> _buildReviewItemsFromDocuments(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    return Future.wait(
      documents.map(
        (document) => _buildReviewItem(
          document.id,
          document.data() ?? <String, dynamic>{},
        ),
      ),
    );
  }

  Future<_ReviewListItem> _buildReviewItem(
    String reviewId,
    Map<String, dynamic> reviewData,
  ) async {
    final String bookId =
        (reviewData['bookId'] as String? ?? '').trim();
    String bookTitle = 'Unknown book';

    if (bookId.isNotEmpty) {
      final DocumentSnapshot<Map<String, dynamic>> bookSnapshot =
          await _firestore.collection('books').doc(bookId).get();
      final String loadedTitle =
          (bookSnapshot.data()?['title'] as String? ?? '').trim();

      if (loadedTitle.isNotEmpty) {
        bookTitle = loadedTitle;
      }
    }

    return _ReviewListItem(
      id: reviewId,
      data: reviewData,
      bookTitle: bookTitle,
    );
  }

  int _compareNewestFirst(
    _ReviewListItem first,
    _ReviewListItem second,
  ) {
    final Timestamp? firstTimestamp = first.data['createdAt'] as Timestamp?;
    final Timestamp? secondTimestamp = second.data['createdAt'] as Timestamp?;

    return (secondTimestamp?.millisecondsSinceEpoch ?? 0).compareTo(
      firstTimestamp?.millisecondsSinceEpoch ?? 0,
    );
  }

  Future<void> _openReview(String reviewId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReviewDetailsScreen(reviewId: reviewId),
      ),
    );

    if (mounted) {
      await _loadReviews();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(title: const Text('My reviews')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadReviews,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _CollapsibleReviewSection(
                      title: 'Your reviews',
                      emptyTitle: 'No reviews yet',
                      emptyDescription: 'Reviews you write will appear here.',
                      reviews: _ownReviews,
                      showActions: true,
                      initiallyExpanded: true,
                      onReviewTap: _openReview,
                    ),
                    const SizedBox(height: 16),
                    _CollapsibleReviewSection(
                      title: 'Reviews you commented on',
                      emptyTitle: 'No commented reviews yet',
                      emptyDescription:
                          'Reviews you comment on will appear here.',
                      reviews: _commentedReviews,
                      showActions: false,
                      initiallyExpanded: false,
                      onReviewTap: _openReview,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CollapsibleReviewSection extends StatefulWidget {
  const _CollapsibleReviewSection({
    required this.title,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.reviews,
    required this.showActions,
    required this.initiallyExpanded,
    required this.onReviewTap,
  });

  final String title;
  final String emptyTitle;
  final String emptyDescription;
  final List<_ReviewListItem> reviews;
  final bool showActions;
  final bool initiallyExpanded;
  final Future<void> Function(String reviewId) onReviewTap;

  @override
  State<_CollapsibleReviewSection> createState() =>
      _CollapsibleReviewSectionState();
}

class _CollapsibleReviewSectionState
    extends State<_CollapsibleReviewSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.charcoal,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (widget.reviews.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sage,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.reviews.length}',
                        style: const TextStyle(
                          color: AppColors.forest,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.forest,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: widget.reviews.isEmpty
                  ? _EmptyReviewSection(
                      title: widget.emptyTitle,
                      description: widget.emptyDescription,
                    )
                  : Column(
                      children: widget.reviews.map((review) {
                        return ReviewCard(
                          reviewId: review.id,
                          review: review.data,
                          showBookTitle: true,
                          bookTitle: review.bookTitle,
                          showActions: widget.showActions,
                          onTap: () => widget.onReviewTap(review.id),
                        );
                      }).toList(),
                    ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _EmptyReviewSection extends StatelessWidget {
  const _EmptyReviewSection({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            color: AppColors.forest,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReviewListItem {
  const _ReviewListItem({
    required this.id,
    required this.data,
    required this.bookTitle,
  });

  final String id;
  final Map<String, dynamic> data;
  final String bookTitle;
}
