import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/message_service.dart';
import '../theme/app_colors.dart';
import '../widgets/book_cover.dart';
import '../widgets/user_avatar.dart';
import 'book_details_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUsername,
    this.otherProfileImage = '',
  });

  final String otherUserId;
  final String otherUsername;
  final String otherProfileImage;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessageService _messageService = MessageService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  bool _isLoading = true;
  bool _isSending = false;

  List<Message> _messages = <Message>[];

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final List<Message> messages =
          await _messageService.getConversation(
        widget.otherUserId,
      );

      await _messageService.markConversationAsRead(
        widget.otherUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

      _scrollToBottom();
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

  Future<void> _sendMessage() async {
    final String content =
        _messageController.text.trim();

    if (content.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _messageService.sendMessage(
        receiverId: widget.otherUserId,
        content: content,
      );

      _messageController.clear();

      await _loadConversation();
    } on Exception catch (error) {
      if (mounted) {
        _showMessage(
          _readableError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _openSharedBook(
    Message message,
  ) async {
    final String? bookId = message.bookId;

    if (bookId == null || bookId.isEmpty) {
      _showMessage(
        'This book is no longer available.',
      );
      return;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
          bookDocument =
          await FirebaseFirestore.instance
              .collection('books')
              .doc(bookId)
              .get();

      if (!mounted) {
        return;
      }

      final Map<String, dynamic>? bookData =
          bookDocument.data();

      if (!bookDocument.exists || bookData == null) {
        _showMessage(
          'This book is no longer available.',
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return BookDetailsScreen(
              bookId: bookDocument.id,
              bookData: bookData,
            );
          },
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      if (error.code == 'permission-denied') {
        _showMessage(
          'You do not have permission to open this book.',
        );
      } else {
        _showMessage(
          'Unable to open the shared book.',
        );
      }
    } on Exception {
      if (mounted) {
        _showMessage(
          'Unable to open the shared book.',
        );
      }
    }
  }

  Future<void> _deleteMessage(
    Message message,
  ) async {
    final bool? shouldDelete =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: const Text(
            'Delete message',
          ),
          content: const Text(
            'Are you sure you want to delete this message?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _messageService.deleteMessage(
        message.id,
      );

      await _loadConversation();
    } on Exception catch (error) {
      if (mounted) {
        _showMessage(
          _readableError(error),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 250,
        ),
        curve: Curves.easeOut,
      );
    });
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
      return 'You do not have permission to access this conversation.';
    }

    if (message.startsWith(
      'Bad state:',
    )) {
      return message.replaceFirst(
        'Bad state: ',
        '',
      );
    }

    if (message.startsWith(
      'Invalid argument(s):',
    )) {
      return message.replaceFirst(
        'Invalid argument(s): ',
        '',
      );
    }

    return 'Unable to complete the message operation.';
  }

  String _otherUserInitials() {
    final String normalized =
        widget.otherUsername.trim();

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

  String _formatMessageTime(
    DateTime? dateTime,
  ) {
    if (dateTime == null) {
      return 'Sending...';
    }

    final DateTime localDate =
        dateTime.toLocal();

    final String hour = localDate.hour
        .toString()
        .padLeft(2, '0');

    final String minute = localDate.minute
        .toString()
        .padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId =
        _firebaseAuth.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(
              initials: _otherUserInitials(),
              radius: 18,
              imageUrl:
                  widget.otherProfileImage.isEmpty
                      ? null
                      : widget.otherProfileImage,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.otherUsername,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadConversation,
            tooltip: 'Refresh messages',
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadConversation,
                      child: _messages.isEmpty
                          ? const _EmptyChatView()
                          : ListView.builder(
                              controller:
                                  _scrollController,
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets
                                      .fromLTRB(
                                16,
                                16,
                                16,
                                24,
                              ),
                              itemCount:
                                  _messages.length,
                              itemBuilder: (
                                BuildContext context,
                                int index,
                              ) {
                                final Message message =
                                    _messages[index];

                                final bool isOwn =
                                    message.senderId ==
                                        currentUserId;

                                return _MessageBubble(
                                  message: message,
                                  isOwn: isOwn,
                                  formattedTime:
                                      _formatMessageTime(
                                    message.sentAt,
                                  ),
                                  onBookTap:
                                      message.isBookMessage
                                          ? () {
                                              _openSharedBook(
                                                message,
                                              );
                                            }
                                          : null,
                                  onLongPress: isOwn
                                      ? () {
                                          _deleteMessage(
                                            message,
                                          );
                                        }
                                      : null,
                                );
                              },
                            ),
                    ),
            ),
            _MessageComposer(
              controller: _messageController,
              isSending: _isSending,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.formattedTime,
    required this.onBookTap,
    required this.onLongPress,
  });

  final Message message;
  final bool isOwn;
  final String formattedTime;
  final VoidCallback? onBookTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 420,
          ),
          margin: const EdgeInsets.only(
            bottom: 10,
          ),
          padding: EdgeInsets.fromLTRB(
            message.isBookMessage ? 8 : 14,
            message.isBookMessage ? 8 : 10,
            message.isBookMessage ? 8 : 14,
            8,
          ),
          decoration: BoxDecoration(
            color: isOwn
                ? AppColors.forest
                : AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(
                isOwn ? 16 : 4,
              ),
              bottomRight: Radius.circular(
                isOwn ? 4 : 16,
              ),
            ),
            border: isOwn
                ? null
                : Border.all(
                    color: AppColors.inputBorder,
                  ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: message.isBookMessage
                    ? _SharedBookCard(
                        message: message,
                        isOwn: isOwn,
                        onTap: onBookTap,
                      )
                    : Text(
                        message.content,
                        style: TextStyle(
                          color: isOwn
                              ? AppColors.white
                              : AppColors.charcoal,
                          height: 1.35,
                        ),
                      ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedTime,
                    style: TextStyle(
                      color: isOwn
                          ? AppColors.white
                              .withValues(
                                alpha: 0.72,
                              )
                          : AppColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                  if (isOwn) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead
                          ? Icons.done_all
                          : Icons.done,
                      size: 15,
                      color: message.isRead
                          ? AppColors.sage
                          : AppColors.white
                              .withValues(
                                alpha: 0.72,
                              ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedBookCard extends StatelessWidget {
  const _SharedBookCard({
    required this.message,
    required this.isOwn,
    required this.onTap,
  });

  final Message message;
  final bool isOwn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = isOwn
        ? AppColors.white
        : AppColors.charcoal;

    final Color secondaryColor = isOwn
        ? AppColors.white.withValues(
            alpha: 0.75,
          )
        : AppColors.secondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isOwn
                ? AppColors.white.withValues(
                    alpha: 0.12,
                  )
                : AppColors.ivory,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOwn
                  ? AppColors.white.withValues(
                      alpha: 0.25,
                    )
                  : AppColors.inputBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              BookCover(
                imageUrl: message.bookCoverUrl,
                width: 58,
                borderRadius: 7,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shared a book',
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message.bookTitle ??
                          'Unknown title',
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message.bookAuthor
                                  ?.isNotEmpty ==
                              true
                          ? message.bookAuthor!
                          : 'Unknown author',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: secondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View book',
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.inputBorder,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isSending,
              minLines: 1,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization:
                  TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Write a message...',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (!isSending) {
                  onSend();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed:
                isSending ? null : onSend,
            tooltip: 'Send message',
            icon: isSending
                ? const SizedBox.square(
                    dimension: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.forum_outlined,
          size: 58,
          color: AppColors.forest,
        ),
        const SizedBox(height: 16),
        Text(
          'Start the conversation',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                color: AppColors.charcoal,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Write the first message using the field below.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color: AppColors.secondary,
              ),
        ),
      ],
    );
  }
}