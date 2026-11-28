import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_search_result.dart';
import '../services/user_search_service.dart';
import '../theme/app_colors.dart';
import '../widgets/review_card.dart';
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
        _firestore.collection('library_entries').get(),
      ]);

      final QuerySnapshot<Map<String, dynamic>> userSnapshot =
          results[0] as QuerySnapshot<Map<String, dynamic>>;
      final QuerySnapshot<Map<String, dynamic>> reviewSnapshot =
          results[1] as QuerySnapshot<Map<String, dynamic>>;
      final QuerySnapshot<Map<String, dynamic>> librarySnapshot =
          results[2] as QuerySnapshot<Map<String, dynamic>>;

      final Map<String, int> bookCounts = <String, int>{};
      for (final QueryDocumentSnapshot<Map<String, dynamic>> document
          in librarySnapshot.docs) {
        final String userId =
            (document.data()['userId'] as String? ?? '').trim();
        if (userId.isNotEmpty) {
          bookCounts[userId] = (bookCounts[userId] ?? 0) + 1;
        }
      }

      final List<_CommunityReader> readers = userSnapshot.docs
          .where((document) => document.id != currentUserId)
          .map((document) {
        final Map<String, dynamic> data = document.data();
        final String username =
            (data['username'] as String? ?? 'Reader').trim();
        final String profileImage =
            (data['profileImage'] as String? ?? '').trim();

        return _CommunityReader(
          id: document.id,
          username: username.isEmpty ? 'Reader' : username,
          profileImage: profileImage,
          bookCount: bookCounts[document.id] ?? 0,
        );
      }).toList()
        ..sort((first, second) =>
            first.username.toLowerCase().compareTo(second.username.toLowerCase()));

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

          return _CommunityReview(
            id: document.id,
            data: review,
            bookTitle: bookTitle,
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
      _showMessage('An unexpected error occurred while loading the community.');
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

    FocusScope.of(context).unfocus();
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
      if (query.isEmpty) {
        _searchResults = <UserSearchResult>[];
        _errorMessage = null;
      } else if (query.length < 2) {
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
    final bool isSearchMode = _searchController.text.trim().isNotEmpty;
    final List<_CommunityReader> visibleReaders =
        _showAllReaders ? _readers : _readers.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadCommunity,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Community',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppColors.charcoal,
                                  fontFamily: 'Serif',
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: _openMessages,
                          tooltip: 'Open messages',
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.forest,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 26),
                    if (isSearchMode) ...[
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
                            bookCount: null,
                            onMessage: () => _openChat(
                              userId: user.id,
                              username: user.username,
                              profileImage: user.profileImage,
                            ),
                          ),
                        ),
                    ] else ...[
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
                      const SizedBox(height: 12),
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
                            bookCount: reader.bookCount,
                            onMessage: () => _openChat(
                              userId: reader.id,
                              username: reader.username,
                              profileImage: reader.profileImage,
                            ),
                          ),
                        ),
                      const SizedBox(height: 26),
                      const _SectionTitle(
                        title: 'Between the pages',
                        actionText: 'Latest',
                        onAction: null,
                      ),
                      const SizedBox(height: 12),
                      if (_reviews.isEmpty)
                        const _EmptyCard(
                          icon: Icons.rate_review_outlined,
                          title: 'No reviews yet',
                          description:
                              'Public reviews will appear here when readers post them.',
                        )
                      else
                        ..._reviews.map(
                          (review) => ReviewCard(
                            reviewId: review.id,
                            review: review.data,
                            showBookTitle: true,
                            bookTitle: review.bookTitle,
                            showActions: false,
                            onTap: () => _openReview(review.id),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _CommunityReader {
  const _CommunityReader({
    required this.id,
    required this.username,
    required this.profileImage,
    required this.bookCount,
  });

  final String id;
  final String username;
  final String profileImage;
  final int bookCount;
}

class _CommunityReview {
  const _CommunityReview({
    required this.id,
    required this.data,
    required this.bookTitle,
  });

  final String id;
  final Map<String, dynamic> data;
  final String bookTitle;
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
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Serif',
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
    required this.bookCount,
    required this.onMessage,
  });

  final String username;
  final String profileImage;
  final String initials;
  final int? bookCount;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
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
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bookCount == null
                      ? 'Public reader'
                      : 'Public reader · $bookCount books',
                  style: const TextStyle(color: AppColors.secondary),
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
            style: const TextStyle(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}
