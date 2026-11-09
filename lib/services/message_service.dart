import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message.dart';

class MessageService {
  MessageService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : _firestore =
            firestore ?? FirebaseFirestore.instance,
        _firebaseAuth =
            firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  CollectionReference<Map<String, dynamic>>
      get _messages {
    return _firestore.collection('messages');
  }

  User _requireCurrentUser() {
    final User? user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'You must be logged in to use messages.',
      );
    }

    return user;
  }

  Future<String> sendMessage({
    required String receiverId,
    required String content,
  }) async {
    final User user = _requireCurrentUser();

    final String normalizedReceiverId =
        receiverId.trim();

    final String normalizedContent =
        content.trim();

    if (normalizedReceiverId.isEmpty) {
      throw ArgumentError(
        'The receiver ID cannot be empty.',
      );
    }

    if (normalizedReceiverId == user.uid) {
      throw ArgumentError(
        'You cannot send a message to yourself.',
      );
    }

    if (normalizedContent.isEmpty) {
      throw ArgumentError(
        'The message cannot be empty.',
      );
    }

    if (normalizedContent.length > 2000) {
      throw ArgumentError(
        'The message cannot be longer than '
        '2000 characters.',
      );
    }

    final DocumentReference<Map<String, dynamic>>
        document = await _messages.add(
      <String, dynamic>{
        'senderId': user.uid,
        'receiverId': normalizedReceiverId,
        'content': normalizedContent,
        'sentAt': FieldValue.serverTimestamp(),
        'isRead': false,
      },
    );

    return document.id;
  }

  Future<List<Message>> getConversation(
    String otherUserId,
  ) async {
    final User user = _requireCurrentUser();

    final String normalizedOtherUserId =
        otherUserId.trim();

    if (normalizedOtherUserId.isEmpty) {
      return <Message>[];
    }

    final Future<
        QuerySnapshot<Map<String, dynamic>>>
        sentRequest = _messages
            .where(
              'senderId',
              isEqualTo: user.uid,
            )
            .where(
              'receiverId',
              isEqualTo: normalizedOtherUserId,
            )
            .get();

    final Future<
        QuerySnapshot<Map<String, dynamic>>>
        receivedRequest = _messages
            .where(
              'senderId',
              isEqualTo: normalizedOtherUserId,
            )
            .where(
              'receiverId',
              isEqualTo: user.uid,
            )
            .get();

    final List<
        QuerySnapshot<Map<String, dynamic>>>
        results = await Future.wait(
      <Future<
          QuerySnapshot<Map<String, dynamic>>>>[
        sentRequest,
        receivedRequest,
      ],
    );

    final List<Message> messages = <Message>[
      ...results[0].docs.map(
        Message.fromFirestore,
      ),
      ...results[1].docs.map(
        Message.fromFirestore,
      ),
    ];

    messages.sort(_compareBySentAt);

    return messages;
  }

  Future<List<Message>>
      getCurrentUserMessages() async {
    final User user = _requireCurrentUser();

    final Future<
        QuerySnapshot<Map<String, dynamic>>>
        sentRequest = _messages
            .where(
              'senderId',
              isEqualTo: user.uid,
            )
            .get();

    final Future<
        QuerySnapshot<Map<String, dynamic>>>
        receivedRequest = _messages
            .where(
              'receiverId',
              isEqualTo: user.uid,
            )
            .get();

    final List<
        QuerySnapshot<Map<String, dynamic>>>
        results = await Future.wait(
      <Future<
          QuerySnapshot<Map<String, dynamic>>>>[
        sentRequest,
        receivedRequest,
      ],
    );

    final Map<String, Message> uniqueMessages =
        <String, Message>{};

    for (final QueryDocumentSnapshot<
        Map<String, dynamic>> document
        in <QueryDocumentSnapshot<
            Map<String, dynamic>>>[
      ...results[0].docs,
      ...results[1].docs,
    ]) {
      uniqueMessages[document.id] =
          Message.fromFirestore(document);
    }

    final List<Message> messages =
        uniqueMessages.values.toList()
          ..sort(_compareBySentAt);

    return messages;
  }

  Future<void> markConversationAsRead(
    String otherUserId,
  ) async {
    final User user = _requireCurrentUser();

    final QuerySnapshot<Map<String, dynamic>>
        snapshot = await _messages
            .where(
              'senderId',
              isEqualTo: otherUserId.trim(),
            )
            .where(
              'receiverId',
              isEqualTo: user.uid,
            )
            .get();

    final WriteBatch batch = _firestore.batch();
    bool hasUpdates = false;

    for (final QueryDocumentSnapshot<
        Map<String, dynamic>> document
        in snapshot.docs) {
      if (document.data()['isRead'] != true) {
        batch.update(
          document.reference,
          <String, dynamic>{
            'isRead': true,
          },
        );

        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  Future<void> deleteMessage(
    String messageId,
  ) async {
    final User user = _requireCurrentUser();

    final DocumentReference<Map<String, dynamic>>
        reference = _messages.doc(
      messageId.trim(),
    );

    final DocumentSnapshot<Map<String, dynamic>>
        snapshot = await reference.get();

    if (!snapshot.exists) {
      return;
    }

    final Map<String, dynamic> data =
        snapshot.data() ?? <String, dynamic>{};

    if (data['senderId'] != user.uid) {
      throw StateError(
        'Only the sender can delete this message.',
      );
    }

    await reference.delete();
  }

  Future<int> getUnreadMessageCount() async {
    final User user = _requireCurrentUser();

    final QuerySnapshot<Map<String, dynamic>>
        snapshot = await _messages
            .where(
              'receiverId',
              isEqualTo: user.uid,
            )
            .where(
              'isRead',
              isEqualTo: false,
            )
            .get();

    return snapshot.size;
  }

  int _compareBySentAt(
    Message first,
    Message second,
  ) {
    final DateTime firstDate =
        first.sentAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

    final DateTime secondDate =
        second.sentAt ??
            DateTime.fromMillisecondsSinceEpoch(0);

    return firstDate.compareTo(secondDate);
  }
}