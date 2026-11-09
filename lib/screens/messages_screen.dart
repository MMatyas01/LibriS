import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/message.dart';
import '../models/user_search_result.dart';
import '../services/message_service.dart';
import '../services/user_search_service.dart';
import '../theme/app_colors.dart';
import '../widgets/user_avatar.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
  });

  @override
  State<MessagesScreen> createState() =>
      _MessagesScreenState();
}

class _MessagesScreenState
    extends State<MessagesScreen> {
  final MessageService _messageService =
      MessageService();

  final UserSearchService _userSearchService =
      UserSearchService();

  final FirebaseAuth _firebaseAuth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _isLoading = true;

  List<_ConversationPreview> _conversations =
      <_ConversationPreview>[];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final String? currentUserId =
        _firebaseAuth.currentUser?.uid;

    if (currentUserId == null) {
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
      final List<Message> messages =
          await _messageService
              .getCurrentUserMessages();

      final Map<String, List<Message>>
          messagesByUser =
          <String, List<Message>>{};

      for (final Message message in messages) {
        final String otherUserId =
            message.otherUserId(currentUserId);

        messagesByUser
            .putIfAbsent(
              otherUserId,
              () => <Message>[],
            )
            .add(message);
      }

      final List<_ConversationPreview>
          conversations =
          <_ConversationPreview>[];

      for (final MapEntry<String, List<Message>>
          entry in messagesByUser.entries) {
        final List<Message> conversationMessages =
            entry.value
              ..sort(_compareNewestFirst);

        final Message lastMessage =
            conversationMessages.first;

        final int unreadCount =
            conversationMessages.where(
          (Message message) {
            return message.receiverId ==
                    currentUserId &&
                !message.isRead;
          },
        ).length;

        final _UserPreview user =
            await _loadUserPreview(entry.key);

        conversations.add(
          _ConversationPreview(
            otherUserId: entry.key,
            username: user.username,
            profileImage: user.profileImage,
            lastMessage: lastMessage,
            unreadCount: unreadCount,
          ),
        );
      }

      conversations.sort(
        (
          _ConversationPreview first,
          _ConversationPreview second,
        ) {
          return _compareNewestFirst(
            first.lastMessage,
            second.lastMessage,
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        _readableError(error),
      );
    }
  }

  Future<_UserPreview> _loadUserPreview(
    String userId,
  ) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>>
          snapshot = await _firestore
              .collection('users')
              .doc(userId)
              .get();

      final Map<String, dynamic>? data =
          snapshot.data();

      final String username =
          (data?['username'] as String? ?? '')
              .trim();

      final String profileImage =
          (data?['profileImage'] as String? ?? '')
              .trim();

      return _UserPreview(
        username: username.isEmpty
            ? _shortUserId(userId)
            : username,
        profileImage: profileImage,
      );
    } catch (_) {
      return _UserPreview(
        username: _shortUserId(userId),
        profileImage: '',
      );
    }
  }

  int _compareNewestFirst(
    Message first,
    Message second,
  ) {
    final DateTime firstDate =
        first.sentAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

    final DateTime secondDate =
        second.sentAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

    return secondDate.compareTo(firstDate);
  }

  Future<void> _openConversation({
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

    if (mounted) {
      await _loadConversations();
    }
  }

  Future<void> _showNewConversationDialog() async {
    final UserSearchResult? selectedUser =
        await showDialog<UserSearchResult>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return _UserSearchDialog(
          userSearchService:
              _userSearchService,
        );
      },
    );

    if (selectedUser == null || !mounted) {
      return;
    }

    await _openConversation(
      userId: selectedUser.id,
      username: selectedUser.username,
      profileImage:
          selectedUser.profileImage,
    );
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

  String _readableError(Object error) {
    final String message = error.toString();

    if (message.contains(
      'permission-denied',
    )) {
      return 'You do not have permission to load these messages.';
    }

    if (message.startsWith(
      'Bad state:',
    )) {
      return message.replaceFirst(
        'Bad state: ',
        '',
      );
    }

    return 'Unable to load your conversations.';
  }

  String _shortUserId(String userId) {
    if (userId.length <= 14) {
      return userId;
    }

    return '${userId.substring(0, 8)}'
        '...'
        '${userId.substring(userId.length - 4)}';
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

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }

    final DateTime now = DateTime.now();
    final DateTime localDate =
        dateTime.toLocal();

    final bool isToday =
        localDate.year == now.year &&
            localDate.month == now.month &&
            localDate.day == now.day;

    if (isToday) {
      final String hour =
          localDate.hour
              .toString()
              .padLeft(2, '0');

      final String minute =
          localDate.minute
              .toString()
              .padLeft(2, '0');

      return '$hour:$minute';
    }

    final String month =
        localDate.month
            .toString()
            .padLeft(2, '0');

    final String day =
        localDate.day
            .toString()
            .padLeft(2, '0');

    return '${localDate.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            onPressed: _loadConversations,
            tooltip: 'Refresh conversations',
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _showNewConversationDialog,
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.white,
        icon: const Icon(
          Icons.edit_square,
        ),
        label: const Text(
          'New message',
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _loadConversations,
                child: _conversations.isEmpty
                    ? _EmptyMessagesView(
                        onStartConversation:
                            _showNewConversationDialog,
                      )
                    : ListView.separated(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          100,
                        ),
                        itemCount:
                            _conversations.length,
                        separatorBuilder:
                            (
                              BuildContext context,
                              int index,
                            ) {
                          return const SizedBox(
                            height: 10,
                          );
                        },
                        itemBuilder:
                            (
                              BuildContext context,
                              int index,
                            ) {
                          final _ConversationPreview
                              conversation =
                              _conversations[
                                  index];

                          return _ConversationCard(
                            username:
                                conversation.username,
                            initials: _initials(
                              conversation.username,
                            ),
                            profileImage:
                                conversation
                                    .profileImage,
                            lastMessage:
                                conversation
                                    .lastMessage
                                    .content,
                            time: _formatTime(
                              conversation
                                  .lastMessage
                                  .sentAt,
                            ),
                            unreadCount:
                                conversation
                                    .unreadCount,
                            isOwnLastMessage:
                                conversation
                                        .lastMessage
                                        .senderId ==
                                    _firebaseAuth
                                        .currentUser
                                        ?.uid,
                            onTap: () {
                              _openConversation(
                                userId: conversation
                                    .otherUserId,
                                username:
                                    conversation
                                        .username,
                                profileImage:
                                    conversation
                                        .profileImage,
                              );
                            },
                          );
                        },
                      ),
              ),
      ),
    );
  }
}

class _UserPreview {
  const _UserPreview({
    required this.username,
    required this.profileImage,
  });

  final String username;
  final String profileImage;
}

class _ConversationPreview {
  const _ConversationPreview({
    required this.otherUserId,
    required this.username,
    required this.profileImage,
    required this.lastMessage,
    required this.unreadCount,
  });

  final String otherUserId;
  final String username;
  final String profileImage;
  final Message lastMessage;
  final int unreadCount;
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.username,
    required this.initials,
    required this.profileImage,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isOwnLastMessage,
    required this.onTap,
  });

  final String username;
  final String initials;
  final String profileImage;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isOwnLastMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasUnread =
        unreadCount > 0;

    return Material(
      color: hasUnread
          ? AppColors.sage
          : AppColors.white,
      borderRadius:
          BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color: hasUnread
                  ? AppColors.forest
                      .withValues(
                        alpha: 0.45,
                      )
                  : AppColors.inputBorder,
            ),
          ),
          child: Row(
            children: [
              UserAvatar(
                initials: initials,
                radius: 24,
                imageUrl:
                    profileImage.isEmpty
                        ? null
                        : profileImage,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            username,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  AppColors.charcoal,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style:
                                const TextStyle(
                              color:
                                  AppColors.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isOwnLastMessage
                                ? 'You: $lastMessage'
                                : lastMessage,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread
                                  ? AppColors.charcoal
                                  : AppColors.secondary,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 10),
                          CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                AppColors.forest,
                            child: Text(
                              unreadCount > 99
                                  ? '99+'
                                  : '$unreadCount',
                              style:
                                  const TextStyle(
                                color: AppColors.white,
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMessagesView
    extends StatelessWidget {
  const _EmptyMessagesView({
    required this.onStartConversation,
  });

  final VoidCallback onStartConversation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        return SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight - 48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 420,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons
                          .chat_bubble_outline,
                      size: 64,
                      color: AppColors.forest,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'No conversations yet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color:
                                AppColors.charcoal,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Search for another reader by username and start a private conversation.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color:
                                AppColors.secondary,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed:
                          onStartConversation,
                      icon: const Icon(
                        Icons
                            .add_comment_outlined,
                      ),
                      label: const Text(
                        'Start conversation',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserSearchDialog extends StatefulWidget {
  const _UserSearchDialog({
    required this.userSearchService,
  });

  final UserSearchService userSearchService;

  @override
  State<_UserSearchDialog> createState() =>
      _UserSearchDialogState();
}

class _UserSearchDialogState
    extends State<_UserSearchDialog> {
  final TextEditingController _controller =
      TextEditingController();

  bool _isSearching = false;
  bool _hasSearched = false;

  List<UserSearchResult> _results =
      <UserSearchResult>[];

  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final String username =
        _controller.text.trim();

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
          await widget.userSearchService
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

  String _initials(String username) {
    final String normalized =
        username.trim();

    if (normalized.length >= 2) {
      return normalized
          .substring(0, 2)
          .toUpperCase();
    }

    if (normalized.isNotEmpty) {
      return normalized[0].toUpperCase();
    }

    return 'US';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'New conversation',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
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
                  onPressed:
                      _isSearching
                          ? null
                          : _search,
                  tooltip: 'Search',
                  icon: const Icon(
                    Icons.search,
                  ),
                ),
              ),
              onSubmitted: (_) {
                if (!_isSearching) {
                  _search();
                }
              },
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(20),
                child:
                    CircularProgressIndicator(),
              )
            else if (_results.isNotEmpty)
              ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxHeight: 260,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder:
                      (
                        BuildContext context,
                        int index,
                      ) {
                    return const Divider(
                      height: 1,
                    );
                  },
                  itemBuilder:
                      (
                        BuildContext context,
                        int index,
                      ) {
                    final UserSearchResult user =
                        _results[index];

                    return ListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      leading: UserAvatar(
                        initials:
                            _initials(
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
                      trailing: const Icon(
                        Icons.chevron_right,
                      ),
                      onTap: () {
                        Navigator.of(context).pop(
                          user,
                        );
                      },
                    );
                  },
                ),
              )
            else if (_hasSearched)
              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  vertical: 20,
                ),
                child: Text(
                  'No public reader found with this username.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        AppColors.secondary,
                  ),
                ),
              )
            else
              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  vertical: 12,
                ),
                child: Text(
                  'Search for a public reader by their exact username.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        AppColors.secondary,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}