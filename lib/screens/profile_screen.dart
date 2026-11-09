import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'messages_screen.dart';

import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../theme/app_colors.dart';
import '../widgets/section_header.dart';
import '../widgets/user_avatar.dart';
import 'edit_profile_screen.dart';
import 'login_screen.dart';
import 'privacy_settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await _firestore.collection('users').doc(user.uid).get();

      final QuerySnapshot<Map<String, dynamic>> librarySnapshot =
          await _firestore
              .collection('library_entries')
              .where('userId', isEqualTo: user.uid)
              .get();

      final Map<String, dynamic>? data = userSnapshot.data();
      final String username = (data?['username'] as String? ?? '').trim();
      final String profileImage =
          (data?['profileImage'] as String? ?? '').trim();
      final Object? readingGoalValue = data?['readingGoal'];

      final int readingGoal =
          readingGoalValue is num ? readingGoalValue.toInt() : 0;

      final int finished = librarySnapshot.docs.where((document) {
        return document.data()['status'] == 'finished';
      }).length;

      if (!mounted) {
        return;
      }

      setState(() {
        _username =
            username.isNotEmpty ? username : _usernameFromEmail(user.email);
        _email = (data?['email'] as String? ?? user.email ?? '').trim();
        _profileImageUrl =
            profileImage.isNotEmpty ? profileImage : user.photoURL;
        _readingGoal = readingGoal;
        _books = librarySnapshot.size;
        _finished = finished;
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      _showMessage(error.message ?? 'Unable to load your profile.');
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      _showMessage('An unexpected error occurred while loading your profile.');
    }
  }

  String _usernameFromEmail(String? email) {
    if (email == null || !email.contains('@')) {
      return 'Reader';
    }

    final String value = email.split('@').first.trim();
    return value.isEmpty ? 'Reader' : value;
  }

  String _getInitials() {
    final List<String> parts = _username
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

    if (parts.isNotEmpty) {
      return parts.first[0].toUpperCase();
    }

    return 'LR';
  }

  Future<void> _openEditProfile() async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const EditProfileScreen(),
      ),
    );

    if (updated == true && mounted) {
      await _loadProfile();
      if (mounted) {
        _showMessage('Profile updated successfully.');
      }
    }
  }

  Future<void> _openPrivacySettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PrivacySettingsScreen(),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showUnavailableFeature(String message) {
    _showMessage(message);
  }

  Future<void> _showLogoutDialog() async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
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
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    await AuthService().signOut();
    await PreferencesService().clearRememberMe();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
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
                    final double horizontalPadding =
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
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const MessagesScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _ProfileStatistics(
                                books: _books,
                                finished: _finished,
                                reviews: 0,
                              ),
                              const SizedBox(height: 28),
                              SectionHeader(
                                title: 'Your reviews',
                                actionText: 'View all',
                                onActionTap: () {
                                  _showUnavailableFeature(
                                    'Your complete review history will be available soon.',
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              const _EmptyReviewsCard(),
                              const SizedBox(height: 20),
                              _PrivacySettingsTile(onTap: _openPrivacySettings),
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
          icon: const Icon(
            Icons.settings_outlined,
            color: AppColors.forest,
          ),
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
    final String? usableImageUrl =
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
          child: OutlinedButton.icon(
            onPressed: onMessages,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Messages'),
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
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.inputBorder);
  }
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
      label: const Text(
        'Log out',
        style: TextStyle(color: AppColors.error),
      ),
    );
  }
}
