import 'package:flutter/material.dart';

import '../models/user_search_result.dart';
import '../services/message_service.dart';
import '../services/user_search_service.dart';
import '../theme/app_colors.dart';
import '../widgets/book_cover.dart';
import '../widgets/user_avatar.dart';

class ShareBookScreen extends StatefulWidget {
  const ShareBookScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    this.bookCoverUrl,
  });

  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String? bookCoverUrl;

  @override
  State<ShareBookScreen> createState() =>
      _ShareBookScreenState();
}

class _ShareBookScreenState
    extends State<ShareBookScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  final UserSearchService _userSearchService =
      UserSearchService();

  final MessageService _messageService =
      MessageService();

  bool _isSearching = false;
  bool _hasSearched = false;
  String? _sendingToUserId;
  String? _errorMessage;

  List<UserSearchResult> _results =
      <UserSearchResult>[];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    final String username =
        _searchController.text.trim();

    if (username.length < 3) {
      setState(() {
        _errorMessage =
            'Enter at least 3 characters.';
        _results = <UserSearchResult>[];
        _hasSearched = false;
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      final List<UserSearchResult> results =
          await _userSearchService
              .searchByUsername(username);

      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _results = <UserSearchResult>[];
        _errorMessage =
            'Unable to search for readers.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _shareWithUser(
    UserSearchResult user,
  ) async {
    if (_sendingToUserId != null) {
      return;
    }

    setState(() {
      _sendingToUserId = user.id;
    });

    try {
      await _messageService.sendBookMessage(
        receiverId: user.id,
        bookId: widget.bookId,
        bookTitle: widget.bookTitle,
        bookAuthor: widget.bookAuthor,
        bookCoverUrl: widget.bookCoverUrl,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Book shared with ${user.username}.',
            ),
          ),
        );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _readableError(error),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _sendingToUserId = null;
        });
      }
    }
  }

  String _readableError(Object error) {
    final String message = error.toString();

    if (message.contains('permission-denied')) {
      return 'You do not have permission to share this book.';
    }

    if (message.startsWith('Bad state: ')) {
      return message.replaceFirst(
        'Bad state: ',
        '',
      );
    }

    if (message.startsWith(
      'Invalid argument(s): ',
    )) {
      return message.replaceFirst(
        'Invalid argument(s): ',
        '',
      );
    }

    return 'Unable to share the book.';
  }

  String _initials(String username) {
    final List<String> parts = username
        .trim()
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

    return 'US';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        title: const Text('Share book'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 620,
            ),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _BookPreview(
                  title: widget.bookTitle,
                  author: widget.bookAuthor,
                  coverUrl: widget.bookCoverUrl,
                ),

                const SizedBox(height: 28),

                Text(
                  'Send to a reader',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _searchController,
                  autofocus: true,
                  autocorrect: false,
                  textInputAction:
                      TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'reader_name',
                    prefixIcon: const Icon(
                      Icons.person_search_outlined,
                    ),
                    errorText: _errorMessage,
                    suffixIcon: IconButton(
                      onPressed: _isSearching
                          ? null
                          : _searchUsers,
                      tooltip: 'Search',
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onSubmitted: (_) {
                    if (!_isSearching) {
                      _searchUsers();
                    }
                  },
                ),

                const SizedBox(height: 18),

                if (_isSearching)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child:
                          CircularProgressIndicator(),
                    ),
                  )
                else if (_results.isNotEmpty)
                  ..._results.map(
                    (UserSearchResult user) {
                      final bool isSending =
                          _sendingToUserId == user.id;

                      return Card(
                        margin:
                            const EdgeInsets.only(
                          bottom: 10,
                        ),
                        child: ListTile(
                          leading: UserAvatar(
                            initials: _initials(
                              user.username,
                            ),
                            radius: 22,
                            imageUrl:
                                user.profileImage.isEmpty
                                    ? null
                                    : user.profileImage,
                          ),
                          title: Text(
                            user.username,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                          subtitle: const Text(
                            'Public account',
                          ),
                          trailing: isSending
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_outlined,
                                ),
                          onTap: _sendingToUserId != null
                              ? null
                              : () {
                                  _shareWithUser(user);
                                },
                        ),
                      );
                    },
                  )
                else if (_hasSearched)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 28,
                    ),
                    child: Text(
                      'No public reader found with this username.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.secondary,
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 20,
                    ),
                    child: Text(
                      'Search for a public reader by their exact username.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookPreview extends StatelessWidget {
  const _BookPreview({
    required this.title,
    required this.author,
    required this.coverUrl,
  });

  final String title;
  final String author;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.inputBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          BookCover(
            imageUrl: coverUrl,
            width: 76,
            borderRadius: 8,
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'SHARING',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        color: AppColors.charcoal,
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 5),

                Text(
                  author.isEmpty
                      ? 'Unknown author'
                      : author,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}