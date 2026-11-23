import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AccountVisibility { public, private }

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AccountVisibility _visibility = AccountVisibility.public;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('users').doc(user.uid).get();
      final String visibility =
          (snapshot.data()?['accountVisibility'] as String? ?? 'public')
              .trim();

      if (!mounted) {
        return;
      }

      setState(() {
        _visibility = visibility == 'private'
            ? AccountVisibility.private
            : AccountVisibility.public;
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage(error.message ?? 'Unable to load privacy settings.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage(
        'An unexpected error occurred while loading privacy settings.',
      );
    }
  }

  Future<void> _saveSettings() async {
    final User? user = _firebaseAuth.currentUser;

    if (user == null || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'accountVisibility': _visibility.name,
      });

      if (!mounted) {
        return;
      }

      _showMessage('Privacy settings saved.');
    } on FirebaseException catch (error) {
      if (mounted) {
        _showMessage(error.message ?? 'Unable to save privacy settings.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'An unexpected error occurred while saving privacy settings.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
      appBar: AppBar(title: const Text('Privacy settings')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final double horizontalPadding =
                      (constraints.maxWidth * 0.06).clamp(16.0, 32.0);

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Choose how you appear to other readers.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 26),
                            const _SettingsSectionLabel(
                              text: 'ACCOUNT VISIBILITY',
                            ),
                            const SizedBox(height: 10),
                            _VisibilityOption(
                              title: 'Public account',
                              description:
                                  'Discoverable in Community and eligible for direct messages.',
                              icon: Icons.public_outlined,
                              selected:
                                  _visibility == AccountVisibility.public,
                              onTap: () {
                                setState(() {
                                  _visibility = AccountVisibility.public;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            _VisibilityOption(
                              title: 'Private account',
                              description:
                                  'Excluded from public reader search and recommendations.',
                              icon: Icons.lock_outline,
                              selected:
                                  _visibility == AccountVisibility.private,
                              onTap: () {
                                setState(() {
                                  _visibility = AccountVisibility.private;
                                });
                              },
                            ),
                            const SizedBox(height: 28),
                            const _SettingsSectionLabel(
                              text: 'READING PROGRESS VISIBILITY',
                            ),
                            const SizedBox(height: 10),
                            const _ReadingProgressComingSoonCard(),
                            const SizedBox(height: 16),
                            const _PolicyInformationCard(),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _isSaving ? null : _saveSettings,
                              child: _isSaving
                                  ? const SizedBox.square(
                                      dimension: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.white,
                                      ),
                                    )
                                  : const Text('Save privacy settings'),
                            ),
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
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  const _VisibilityOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.sage : AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.forest : AppColors.inputBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.forest : AppColors.secondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? AppColors.forest : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.forest : AppColors.secondary,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check,
                        size: 15,
                        color: AppColors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingProgressComingSoonCard extends StatelessWidget {
  const _ReadingProgressComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.visibility_outlined, color: AppColors.secondary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reading progress visibility',
                  style: TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'This setting will be available in a later update.',
                  style: TextStyle(
                    color: AppColors.secondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Chip(label: Text('Coming soon')),
        ],
      ),
    );
  }
}

class _PolicyInformationCard extends StatelessWidget {
  const _PolicyInformationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.forest, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Account visibility controls whether other readers can discover your profile.',
              style: TextStyle(color: AppColors.forest, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
