import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
  });

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _usernameController =
      TextEditingController();

  final TextEditingController _readingGoalController =
      TextEditingController();

  final TextEditingController _profileImageController =
      TextEditingController();

  final FirebaseAuth _firebaseAuth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;

  String _email = '';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _readingGoalController.dispose();
    _profileImageController.dispose();
    super.dispose();
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

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          snapshot = await _firestore
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic>? data =
          snapshot.data();

      final String username =
          (data?['username'] as String? ?? '').trim();

      final String profileImage =
          (data?['profileImage'] as String? ?? '')
              .trim();

      final Object? readingGoalValue =
          data?['readingGoal'];

      final int readingGoal =
          readingGoalValue is num
              ? readingGoalValue.toInt()
              : 0;

      _email =
          (data?['email'] as String? ??
                  user.email ??
                  '')
              .trim();

      _usernameController.text =
          username.isNotEmpty
              ? username
              : _usernameFromEmail(user.email);

      _readingGoalController.text =
          readingGoal.toString();

      _profileImageController.text =
          profileImage;

      _profileImageUrl =
          profileImage.isNotEmpty
              ? profileImage
              : null;
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message ??
            'Unable to load your profile.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'An unexpected error occurred while '
        'loading your profile.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final FormState? formState =
        _formKey.currentState;

    if (formState == null ||
        !formState.validate() ||
        _isSaving) {
      return;
    }

    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      _showMessage(
        'You must be logged in to update your profile.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final String username =
          _usernameController.text.trim();

      final int readingGoal = int.parse(
        _readingGoalController.text.trim(),
      );

      final String profileImageUrl =
          _profileImageController.text.trim();

      /*
       * This updates only fields that already exist
       * in the current Firestore user structure.
       *
       * It does not create or modify:
       * - updatedAt
       * - displayName
       * - bio
       * - email
       * - createdAt
       * - accountVisibility
       */
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update(
        <String, dynamic>{
          'username': username,
          'readingGoal': readingGoal,
          'profileImage': profileImageUrl,
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message ??
            'Unable to update your profile.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'An unexpected error occurred while '
        'saving your profile.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  void _clearProfileImage() {
    setState(() {
      _profileImageController.clear();
      _profileImageUrl = null;
    });
  }

  String _usernameFromEmail(String? email) {
    if (email == null || !email.contains('@')) {
      return '';
    }

    return email.split('@').first;
  }

  String _getInitials() {
    final String username =
        _usernameController.text.trim();

    final List<String> parts = username
        .split(RegExp(r'[\s._-]+'))
        .where(
          (String part) => part.isNotEmpty,
        )
        .toList();

    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'
          .toUpperCase();
    }

    if (parts.isNotEmpty &&
        parts.first.length >= 2) {
      return parts.first
          .substring(0, 2)
          .toUpperCase();
    }

    if (parts.isNotEmpty) {
      return parts.first[0].toUpperCase();
    }

    if (_email.isNotEmpty) {
      return _email[0].toUpperCase();
    }

    return 'LR';
  }

  bool _isValidHttpUrl(String value) {
    final Uri? uri = Uri.tryParse(value);

    if (uri == null) {
      return false;
    }

    return uri.hasScheme &&
        uri.hasAuthority &&
        (uri.scheme == 'https' ||
            uri.scheme == 'http');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        title: const Text(
          'Edit profile',
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : LayoutBuilder(
                builder: (
                  BuildContext context,
                  BoxConstraints constraints,
                ) {
                  final double horizontalPadding =
                      (constraints.maxWidth * 0.06)
                          .clamp(
                    16.0,
                    32.0,
                  );

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior
                            .onDrag,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(
                          maxWidth: 620,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .stretch,
                            children: [
                              _buildAvatar(),

                              const SizedBox(height: 28),

                              TextFormField(
                                initialValue: _email,
                                enabled: false,
                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'Email address',
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                  ),
                                  helperText:
                                      'Your email address '
                                      'cannot be changed here.',
                                ),
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller:
                                    _usernameController,
                                enabled: !_isSaving,
                                textInputAction:
                                    TextInputAction.next,
                                autocorrect: false,
                                maxLength: 30,
                                onChanged: (_) {
                                  setState(() {});
                                },
                                decoration:
                                    const InputDecoration(
                                  labelText: 'Username',
                                  hintText: 'reader_name',
                                  prefixIcon: Icon(
                                    Icons.alternate_email,
                                  ),
                                ),
                                validator:
                                    (String? value) {
                                  final String username =
                                      value?.trim() ?? '';

                                  if (username.isEmpty) {
                                    return 'Enter a username.';
                                  }

                                  if (username.length < 3) {
                                    return 'The username must '
                                        'be at least 3 '
                                        'characters long.';
                                  }

                                  final RegExp pattern =
                                      RegExp(
                                    r'^[a-zA-Z0-9._-]+$',
                                  );

                                  if (!pattern.hasMatch(
                                    username,
                                  )) {
                                    return 'Use only letters, '
                                        'numbers, dots, '
                                        'underscores, and '
                                        'hyphens.';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller:
                                    _profileImageController,
                                enabled: !_isSaving,
                                keyboardType:
                                    TextInputType.url,
                                textInputAction:
                                    TextInputAction.next,
                                autocorrect: false,
                                onChanged: (String value) {
                                  final String url =
                                      value.trim();

                                  setState(() {
                                    _profileImageUrl =
                                        url.isEmpty
                                            ? null
                                            : url;
                                  });
                                },
                                decoration:
                                    InputDecoration(
                                  labelText:
                                      'Profile image URL',
                                  hintText:
                                      'https://i.imgur.com/example.jpeg',
                                  prefixIcon: const Icon(
                                    Icons.image_outlined,
                                  ),
                                  helperText:
                                      'Enter a direct link to '
                                      'a JPG, PNG, or WebP image.',
                                  suffixIcon:
                                      _profileImageController
                                              .text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : IconButton(
                                              onPressed:
                                                  _isSaving
                                                      ? null
                                                      : _clearProfileImage,
                                              tooltip:
                                                  'Remove profile image',
                                              icon:
                                                  const Icon(
                                                Icons
                                                    .close,
                                              ),
                                            ),
                                ),
                                validator:
                                    (String? value) {
                                  final String url =
                                      value?.trim() ?? '';

                                  /*
                                   * A profile image is
                                   * optional. An empty value
                                   * displays the initials.
                                   */
                                  if (url.isEmpty) {
                                    return null;
                                  }

                                  if (!_isValidHttpUrl(
                                    url,
                                  )) {
                                    return 'Enter a valid '
                                        'HTTP or HTTPS '
                                        'image URL.';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller:
                                    _readingGoalController,
                                enabled: !_isSaving,
                                keyboardType:
                                    TextInputType.number,
                                textInputAction:
                                    TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_isSaving) {
                                    _saveProfile();
                                  }
                                },
                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'Annual reading goal',
                                  hintText: '12',
                                  prefixIcon: Icon(
                                    Icons.flag_outlined,
                                  ),
                                  suffixText: 'books',
                                ),
                                validator:
                                    (String? value) {
                                  final String input =
                                      value?.trim() ?? '';

                                  if (input.isEmpty) {
                                    return 'Enter your '
                                        'reading goal.';
                                  }

                                  final int? goal =
                                      int.tryParse(input);

                                  if (goal == null) {
                                    return 'Enter a valid '
                                        'whole number.';
                                  }

                                  if (goal < 0) {
                                    return 'The reading goal '
                                        'cannot be negative.';
                                  }

                                  if (goal > 1000) {
                                    return 'The reading goal '
                                        'cannot be greater '
                                        'than 1000.';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 24),

                              FilledButton(
                                onPressed: _isSaving
                                    ? null
                                    : _saveProfile,
                                child: _isSaving
                                    ? const SizedBox.square(
                                        dimension: 22,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color:
                                              AppColors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Save changes',
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildAvatar() {
    final String? usableImageUrl =
        _profileImageUrl?.trim().isNotEmpty == true &&
                _isValidHttpUrl(
                  _profileImageUrl!.trim(),
                )
            ? _profileImageUrl!.trim()
            : null;

    return Column(
      children: [
        UserAvatar(
          initials: _getInitials(),
          radius: 46,
          imageUrl: usableImageUrl,
        ),

        const SizedBox(height: 12),

        Text(
          usableImageUrl == null
              ? 'Enter a direct image URL below '
                  'to add a profile picture.'
              : 'Profile image preview',
          textAlign: TextAlign.center,
          style:
              Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.secondary,
                  ),
        ),
      ],
    );
  }
}