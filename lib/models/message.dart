import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.sentAt,
    required this.isRead,
    this.type = 'text',
    this.bookId,
    this.bookTitle,
    this.bookAuthor,
    this.bookCoverUrl,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime? sentAt;
  final bool isRead;

  // Üzenettípus: "text" vagy "book".
  final String type;

  // Könyvmegosztás esetén kitöltött mezők.
  final String? bookId;
  final String? bookTitle;
  final String? bookAuthor;
  final String? bookCoverUrl;

  factory Message.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    final Object? sentAtValue = data['sentAt'];

    return Message(
      id: document.id,
      senderId: data['senderId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      sentAt: sentAtValue is Timestamp
          ? sentAtValue.toDate()
          : null,
      isRead: data['isRead'] as bool? ?? false,

      // A régi üzenetekben nincs type mező, ezért azok text típusúak.
      type: data['type'] as String? ?? 'text',

      bookId: data['bookId'] as String?,
      bookTitle: data['bookTitle'] as String?,
      bookAuthor: data['bookAuthor'] as String?,
      bookCoverUrl: data['bookCoverUrl'] as String?,
    );
  }

  bool isSentBy(String userId) {
    return senderId == userId;
  }

  String otherUserId(String currentUserId) {
    if (senderId == currentUserId) {
      return receiverId;
    }

    return senderId;
  }

  bool get isBookMessage {
    return type == 'book' && bookId != null && bookId!.isNotEmpty;
  }
}