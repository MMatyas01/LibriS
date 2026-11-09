import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.sentAt,
    required this.isRead,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime? sentAt;
  final bool isRead;

  factory Message.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    final Object? sentAtValue = data['sentAt'];

    return Message(
      id: document.id,
      senderId: data['senderId'] as String? ?? '',
      receiverId:
          data['receiverId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      sentAt: sentAtValue is Timestamp
          ? sentAtValue.toDate()
          : null,
      isRead: data['isRead'] as bool? ?? false,
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
}