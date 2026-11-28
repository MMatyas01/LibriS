import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_search_result.dart';
import '../services/user_search_service.dart';
import '../theme/app_colors.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'messages_screen.dart';
import 'review_details_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final UserSearchService _userSearchService = UserSearchService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _showAllReaders = false;
  String? _errorMessage;

  List<_CommunityReader> _readers = <_CommunityReader>[];
  List<_CommunityReview> _reviews = <_CommunityReview>[];
  List<UserSearchResult> _searchResults = <UserSearchResult>[];

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunity() async {
    final String? currentUserId = _firebaseAuth.currentUser?.uid;

    if (currentUserId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final List<dynamic> results = await Future.wait<dynamic>([
        _firestore
            .collection('users')
            .where('accountVisibility', isEqualTo: 'public')
            .limit(30)
            .get(),
        _firestore.collection('reviews').get(),
      ]);

      final QuerySnapshot<Map<String, dynamic>> userSnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;
      final QuerySnapshot<Map<String, dynamic>> reviewSnapshot =
          results[1] as QuerySnapshot<Map<String, dynamic>>;

      final Map<String, _CommunityReader> publicReaders =
          <String, _CommunityReader>{};

      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in userSnapshot.docs) {
        final Map<String, dynamic> data = document.data();
        final String username =
            (data['username'] as String? ?? 'Reader').trim();
        final String profileImage =
            (data['profileImage'] as String? ?? '').trim();
        final Object? readingGoalValue = data['readingGoal'];

        publicReaders[document.id] = _CommunityReader(
          id: document.id,
          username: username.isEmpty ? 'Reader' : username,
          profileImage: profileImage,
          readingGoal:
              readingGoalValue is num ? readingGoalValue.toInt() : 0,
        );
      }

      final List<_CommunityReader> readers = publicReaders.values
          .where((reader) => reader.id != currentUserId)
          .toList()
        ..sort(
          (first, second) => first.username
              .toLowerCase()
              .compareTo(second.username.toLowerCase()),
        );

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> reviewDocuments =
          reviewSnapshot.docs.toList()
            ..sort((first, second) {
              final Timestamp? firstDate =
                  first.data()['createdAt'] as Timestamp?;
              final Timestamp? secondDate =
                  second.data()['createdAt'] as Timestamp?;

              return (secondDate?.millisecondsSinceEpoch ?? 0)
                  .compareTo(firstDate?.millisecondsSinceEpoch ?? 0);
            });

      final List<_CommunityReview> reviews = await Future.wait(
        reviewDocuments.take(10).map((document) async {
          final Map<String, dynamic> review = document.data();
          final String bookId =
              (review['bookId'] as String? ?? '').trim();
          final String authorId =
              (review['userId'] as String? ?? '').trim();

          String bookTitle = 'Unknown book';
          _CommunityReader? author = publicReaders[authorId];

          if (bookId.isNotEmpty) {
            final DocumentSnapshot<Map<String, dynamic>> bookSnapshot =
                await _firestore.collection('books').doc(bookId).get();
            final String loadedTitle =
                (bookSnapshot.data()?['title'] as String? ?? '').trim();

            if (loadedTitle.isNotEmpty) {
              bookTitle = loadedTitle;
            }
          }

          if (author == null && authorId == currentUserId) {
            final DocumentSnapshot<Map<String, dynamic>> ownSnapshot =
                await _firestore.collection('users').doc(authorId).get();
            final Map<String, dynamic>? ownData = ownSnapshot.data();

            if (ownData != null) {
              author = _CommunityReader(
                id: authorId,
                username:
                    (ownData['username'] as String? ?? 'Reader').trim(),
                profileImage:
                    (ownData['profileImage'] as String? ?? '').trim(),
                readingGoal: (ownData['readingGoal'] as num?)?.toInt() ?? 0,
              );
            }
          }

          return _CommunityReview(
            id: document.id,
            data: review,
            bookTitle: bookTitle,
            authorName: author?.username ?? 'Anonymous Reader',
            authorImage: author?.profileImage ?? '',
          );
        }),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _readers = readers;
        _reviews = reviews;
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      _showMessage(error.message ?? 'Unable to load the community.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      _showMessage(
        'An unexpected error occurred while loading the community.',
      );
    }
  }

  Future<void> _searchReaders() async {
    final String query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = <UserSearchResult>[];
        _errorMessage = null;
      });
      return;
    }

    if (query.length < 2) {
      setState(() {
        _searchResults = <UserSearchResult>[];
        _errorMessage = 'Enter at least 2 characters.';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final List<UserSearchResult> results =
          await _userSearchService.searchByUsername(query);

      if (!mounted) {
        return;
      }

      setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to search for readers.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final String query = value.trim();

    setState(() {
      if (query.length < 2) {
        _searchResults = <UserSearchResult>[];
        _errorMessage = null;
      }
    });

    if (query.length < 2) {
      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      _searchReaders,
    );
  }

  Future<void> _openMessages() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MessagesScreen(),
      ),
    );
  }

  Future<void> _openChat({
    required String userId,
    required String username,
    required String profileImage,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          otherUserId: userId,
          otherUsername: username,
          otherProfileImage: profileImage,
        ),
      ),
    );
  }

  Future<void> _openReview(String reviewId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReviewDetailsScreen(reviewId: reviewId),
      ),
    );

    if (mounted) {
      await _loadCommunity();
    }
  }

  String _initials(String username) {
    final List<String> parts = username
        .trim()
        .split(RegExp(r'[\s._-]+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }

    if (parts.isNotEmpty && parts.first.length >= 2) {
      return parts.first.substring(0, 2).toUpperCase();
    }

    return parts.isNotEmpty ? parts.first[0].toUpperCase() : 'US';
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
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isPortrait =
                constraints.maxHeight >= constraints.maxWidth;
            final double widthFactor = isPortrait ? 1 : 0.58;
            final double horizontalPadding =
                constraints.maxWidth * (isPortrait ? 0.055 : 0.025);
            final bool isSearchMode =
                _searchController.text.trim().isNotEmpty;
            final List<_CommunityReader> visibleReaders =
                _showAllReaders ? _readers : _readers.take(3).toList();

            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: _loadCommunity,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  constraints.maxHeight * 0.025,
                  horizontalPadding,
                  constraints.maxHeight * 0.04,
                ),
                child: FractionallySizedBox(
                  widthFactor: widthFactor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CommunityHeader(onMessages: _openMessages),
                      SizedBox(height: constraints.maxHeight * 0.025),
                      TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: 'Search public readers',
                          prefixIcon: const Icon(Icons.search),
                          errorText: _errorMessage,
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  onPressed: _searchReaders,
                                  tooltip: 'Search readers',
                                  icon: const Icon(Icons.tune),
                                ),
                        ),
                        onChanged: _onSearchChanged,
                        onSubmitted: (_) => _searchReaders(),
                      ),
                      SizedBox(height: constraints.maxHeight * 0.03),
                      if (isSearchMode)
                        _buildSearchResults()
                      else ...[
                        _SectionTitle(
                          title: 'Find your people',
                          actionText: _readers.length > 3
                              ? (_showAllReaders ? 'Show less' : 'See all')
                              : null,
                          onAction: _readers.length > 3
                              ? () {
                                  setState(() {
                                    _showAllReaders = !_showAllReaders;
                                  });
                                }
                              : null,
                        ),
                        SizedBox(height: constraints.maxHeight * 0.012),
                        if (visibleReaders.isEmpty)
                          const _EmptyCard(
                            icon: Icons.people_outline,
                            title: 'No public readers yet',
                            description:
                                'Public readers will appear here when they join.',
                          )
                        else
                          ...visibleReaders.map(
                            (reader) => _ReaderCard(
                              username: reader.username,
                              profileImage: reader.profileImage,
                              initials: _initials(reader.username),
                              readingGoal: reader.readingGoal,
                              onMessage: () => _openChat(
                                userId: reader.id,
                                username: reader.username,
                                profileImage: reader.profileImage,
                              ),
                            ),
                          ),
                        SizedBox(height: constraints.maxHeight * 0.025),
                        const _SectionTitle(
                          title: 'Between the pages',
                          actionText: 'Latest',
                          onAction: null,
                        ),
                        SizedBox(height: constraints.maxHeight * 0.012),
                        if (_reviews.isEmpty)
                          const _EmptyCard(
                            icon: Icons.rate_review_outlined,
                            title: 'No reviews yet',
                            description:
                                'Public reviews will appear here when readers post them.',
                          )
                        else
                          ..._reviews.map(
                            (review) => _CommunityReviewCard(
                              review: review,
                              initials: _initials(review.authorName),
                              onTap: () => _openReview(review.id),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          title: 'Search results',
          actionText: null,
          onAction: null,
        ),
        const SizedBox(height: 12),
        if (_searchResults.isEmpty && !_isSearching)
          const _EmptyCard(
            icon: Icons.person_search_outlined,
            title: 'No public reader found',
            description:
                'Enter the first two or more characters of a public username.',
          )
        else
          ..._searchResults.map(
            (user) => _ReaderCard(
              username: user.username,
              profileImage: user.profileImage,
              initials: _initials(user.username),
              readingGoal: null,
              onMessage: () => _openChat(
                userId: user.id,
                username: user.username,
                profileImage: user.profileImage,
              ),
            ),
          ),
      ],
    );
  }
}

class _CommunityReader {
  const _CommunityReader({
    required this.id,
    required this.username,
    required this.profileImage,
    required this.readingGoal,
  });

  final String id;
  final String username;
  final String profileImage;
  final int readingGoal;
}

class _CommunityReview {
  const _CommunityReview({
    required this.id,
    required this.data,
    required this.bookTitle,
    required this.authorName,
    required this.authorImage,
  });

  final String id;
  final Map<String, dynamic> data;
  final String bookTitle;
  final String authorName;
  final String authorImage;
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({required this.onMessages});

  final VoidCallback onMessages;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Community',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        IconButton(
          onPressed: onMessages,
          tooltip: 'Open messages',
          icon: const Icon(
            Icons.chat_bubble_outline,
            color: AppColors.forest,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.actionText,
    required this.onAction,
  });

  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        if (actionText != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionText!),
          ),
      ],
    );
  }
}

class _ReaderCard extends StatelessWidget {
  const _ReaderCard({
    required this.username,
    required this.profileImage,
    required this.initials,
    required this.readingGoal,
    required this.onMessage,
  });

  final String username;
  final String profileImage;
  final String initials;
  final int? readingGoal;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final String description = readingGoal == null || readingGoal == 0
        ? 'Public reader'
        : 'Public reader · Goal: $readingGoal books';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          UserAvatar(
            initials: initials,
            radius: 23,
            imageUrl: profileImage.isEmpty ? null : profileImage,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontFamily: 'Arial',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onMessage,
            tooltip: 'Message reader',
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityReviewCard extends StatelessWidget {
  const _CommunityReviewCard({
    required this.review,
    required this.initials,
    required this.onTap,
  });

  final _CommunityReview review;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int rating = (review.data['rating'] as num?)?.toInt() ?? 0;
    final String title =
        (review.data['reviewTitle'] as String? ?? '').trim();
    final String body = (review.data['reviewBody'] as String? ??
            review.data['text'] as String? ??
            'No review text provided.')
        .trim();
    final List<dynamic> likedBy =
        review.data['likedBy'] as List<dynamic>? ?? <dynamic>[];
    final Timestamp? createdAt = review.data['createdAt'] as Timestamp?;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  initials: initials,
                  radius: 18,
                  imageUrl:
                      review.authorImage.isEmpty ? null : review.authorImage,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.charcoal,
                          fontFamily: 'Arial',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${review.bookTitle} · ${_formatRelativeDate(createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.secondary,
                          fontFamily: 'Arial',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RatingStars(rating: rating),
              ],
            ),
            const SizedBox(height: 14),
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.secondary,
                fontFamily: 'Arial',
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Metric(
                  icon: Icons.favorite_border,
                  text: '${likedBy.length}',
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('review_comments')
                      .where('reviewId', isEqualTo: review.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    return _Metric(
                      icon: Icons.chat_bubble_outline,
                      text: '${snapshot.data?.docs.length ?? 0} comments',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatRelativeDate(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Recently';
    }

    final Duration difference = DateTime.now().difference(timestamp.toDate());

    if (difference.inDays >= 365) {
      return '${difference.inDays ~/ 365}y ago';
    }
    if (difference.inDays >= 30) {
      return '${difference.inDays ~/ 30}mo ago';
    }
    if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    }
    if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    }
    if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    }

    return 'Just now';
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: AppColors.terracotta,
          size: 16,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.forest),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.secondary,
            fontFamily: 'Arial',
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38, color: AppColors.forest),
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
            style: const TextStyle(
              color: AppColors.secondary,
              fontFamily: 'Arial',
            ),
          ),
        ],
      ),
    );
  }
}
