import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'my_reviews_screen.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_colors.dart';
import '../widgets/review_card.dart';
import '../widgets/section_header.dart';
import '../widgets/user_avatar.dart';
import '../widgets/unread_messages_badge.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'messages_screen.dart';
import 'privacy_settings_screen.dart';
import 'review_details_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _username = 'Reader';
  String _email = '';
  String? _profileImageUrl;
  int _readingGoal = 0;
  int _books = 0;
  int _finished = 0;
  List<_ProfileReview> _reviews = <_ProfileReview>[];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final results = await Future.wait<dynamic>([
        _firestore.collection('users').doc(user.uid).get(),
        _firestore
            .collection('library_entries')
            .where('userId', isEqualTo: user.uid)
            .get(),
        _firestore
            .collection('reviews')
            .where('userId', isEqualTo: user.uid)
            .get(),
      ]);

      final userSnapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final librarySnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final reviewSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;

      final Map<String, dynamic>? userData = userSnapshot.data();
      final String username = (userData?['username'] as String? ?? '').trim();
      final String profileImage =
          (userData?['profileImage'] as String? ?? '').trim();
      final Object? goalValue = userData?['readingGoal'];

      final int finished = librarySnapshot.docs
          .where((doc) => doc.data()['status'] == 'finished')
          .length;

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> reviewDocs =
          reviewSnapshot.docs.toList()
            ..sort((a, b) {
              final aDate = a.data()['createdAt'] as Timestamp?;
              final bDate = b.data()['createdAt'] as Timestamp?;
              return (bDate?.millisecondsSinceEpoch ?? 0)
                  .compareTo(aDate?.millisecondsSinceEpoch ?? 0);
            });

      final List<_ProfileReview> reviews = await Future.wait(
        reviewDocs.map((doc) async {
          final Map<String, dynamic> review = doc.data();
          final String bookId = (review['bookId'] as String? ?? '').trim();
          String bookTitle = 'Unknown book';

          if (bookId.isNotEmpty) {
            final bookSnapshot =
                await _firestore.collection('books').doc(bookId).get();
            bookTitle =
                (bookSnapshot.data()?['title'] as String? ?? 'Unknown book')
                    .trim();
          }

          return _ProfileReview(
            id: doc.id,
            data: review,
            bookTitle: bookTitle.isEmpty ? 'Unknown book' : bookTitle,
          );
        }),
      );

      if (!mounted) return;

      setState(() {
        _username =
            username.isNotEmpty ? username : _usernameFromEmail(user.email);
        _email = (userData?['email'] as String? ?? user.email ?? '').trim();
        _profileImageUrl =
            profileImage.isNotEmpty ? profileImage : user.photoURL;
        _readingGoal = goalValue is num ? goalValue.toInt() : 0;
        _books = librarySnapshot.size;
        _finished = finished;
        _reviews = reviews;
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(error.message ?? 'Unable to load your profile.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('An unexpected error occurred while loading your profile.');
    }
  }

  String _usernameFromEmail(String? email) {
    if (email == null || !email.contains('@')) return 'Reader';
    final value = email.split('@').first.trim();
    return value.isEmpty ? 'Reader' : value;
  }

  String _getInitials() {
    final parts = _username
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
    return parts.isNotEmpty ? parts.first[0].toUpperCase() : 'LR';
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (updated == true && mounted) {
      await _loadProfile();
      if (mounted) _showMessage('Profile updated successfully.');
    }
  }

  Future<void> _openPrivacySettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
    );
  }

  Future<void> _openReview(String reviewId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReviewDetailsScreen(reviewId: reviewId),
      ),
    );
    if (mounted) await _loadProfile();
  }

  Future<void> _showAllReviews() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const MyReviewsScreen(),
      ),
    );

    if (mounted) {
      await _loadProfile();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;
    await AuthService().signOut();
    await PreferencesService().clearRememberMe();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProfile,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding =
                        (constraints.maxWidth * 0.06).clamp(16.0, 32.0);
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        32,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ProfileHeader(
                                onSettingsPressed: _openPrivacySettings,
                              ),
                              const SizedBox(height: 28),
                              _ProfileIdentity(
                                username: _username,
                                email: _email,
                                initials: _getInitials(),
                                imageUrl: _profileImageUrl,
                                readingGoal: _readingGoal,
                              ),
                              const SizedBox(height: 20),
                              _ProfileActions(
                                onEditProfile: _openEditProfile,
                                onMessages: () {
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => const MessagesScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _ProfileStatistics(
                                books: _books,
                                finished: _finished,
                                reviews: _reviews.length,
                              ),
                              const SizedBox(height: 28),
                              SectionHeader(
                                title: 'Your reviews',
                                actionText: 'View all',
                                onActionTap: _showAllReviews,
                              ),
                              const SizedBox(height: 12),
                              if (_reviews.isEmpty)
                                const _EmptyReviewsCard()
                              else
                                ..._reviews.take(3).map(
                                      (review) => ReviewCard(
                                        reviewId: review.id,
                                        review: review.data,
                                        showBookTitle: true,
                                        bookTitle: review.bookTitle,
                                        showActions: true,
                                        onTap: () => _openReview(review.id),
                                      ),
                                    ),
                              const SizedBox(height: 20),
                              _PrivacySettingsTile(
                                onTap: _openPrivacySettings,
                              ),
                              const SizedBox(height: 12),
                              _LogoutTile(onTap: _showLogoutDialog),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _ProfileReview {
  const _ProfileReview({
    required this.id,
    required this.data,
    required this.bookTitle,
  });

  final String id;
  final Map<String, dynamic> data;
  final String bookTitle;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.onSettingsPressed});
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'My profile',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        IconButton(
          onPressed: onSettingsPressed,
          tooltip: 'Privacy settings',
          icon: const Icon(Icons.settings_outlined, color: AppColors.forest),
        ),
      ],
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({
    required this.username,
    required this.email,
    required this.initials,
    required this.imageUrl,
    required this.readingGoal,
  });

  final String username;
  final String email;
  final String initials;
  final String? imageUrl;
  final int readingGoal;

  @override
  Widget build(BuildContext context) {
    final usableImageUrl =
        imageUrl?.trim().isNotEmpty == true ? imageUrl : null;
    return Column(
      children: [
        UserAvatar(
          initials: initials,
          radius: 42,
          imageUrl: usableImageUrl,
        ),
        const SizedBox(height: 14),
        Text(
          username,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 6),
        Text(
          readingGoal > 0
              ? 'Annual reading goal: $readingGoal books'
              : 'No annual reading goal set.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.secondary,
              ),
        ),
      ],
    );
  }
}

class _ProfileActions extends StatelessWidget {
  const _ProfileActions({
    required this.onEditProfile,
    required this.onMessages,
  });
  final VoidCallback onEditProfile;
  final VoidCallback onMessages;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEditProfile,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit profile'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: UnreadMessagesBadge(
            top: -7,
            right: -7,
            child: OutlinedButton.icon(
              onPressed: onMessages,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Messages'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileStatistics extends StatelessWidget {
  const _ProfileStatistics({
    required this.books,
    required this.finished,
    required this.reviews,
  });
  final int books;
  final int finished;
  final int reviews;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          Expanded(child: _StatisticItem(value: books, label: 'Books')),
          const _StatisticDivider(),
          Expanded(child: _StatisticItem(value: finished, label: 'Finished')),
          const _StatisticDivider(),
          Expanded(child: _StatisticItem(value: reviews, label: 'Reviews')),
        ],
      ),
    );
  }
}

class _StatisticItem extends StatelessWidget {
  const _StatisticItem({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.charcoal,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.secondary,
              ),
        ),
      ],
    );
  }
}

class _StatisticDivider extends StatelessWidget {
  const _StatisticDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.inputBorder);
}

class _EmptyReviewsCard extends StatelessWidget {
  const _EmptyReviewsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.rate_review_outlined,
            color: AppColors.forest,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            'No reviews yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your book reviews will appear here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PrivacySettingsTile extends StatelessWidget {
  const _PrivacySettingsTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.privacy_tip_outlined, color: AppColors.forest),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Privacy & reading visibility',
                  style: TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.logout, color: AppColors.error),
      label: const Text('Log out', style: TextStyle(color: AppColors.error)),
    );
  }
}
