import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UnreadMessagesBadge extends StatelessWidget {
  const UnreadMessagesBadge({
    super.key,
    required this.child,
    this.showZero = false,
    this.top = -6,
    this.right = -8,
  });

  final Widget child;
  final bool showZero;
  final double top;
  final double right;

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return child;
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        final int unreadCount = snapshot.data?.docs.where((document) {
              return document.data()['isRead'] != true;
            }).length ??
            0;

        if (unreadCount == 0 && !showZero) {
          return child;
        }

        return Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              top: top,
              right: right,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
