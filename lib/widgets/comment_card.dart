// lib/widgets/comment_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class CommentCard extends StatelessWidget {
  final String commentId; // ÚJ: szükség van az ID-ra a szerkesztéshez/törléshez
  final Map<String, dynamic> comment;
  final bool showActions; // ÚJ: Ha igaz, megjelenik a kebab menü (ha a user a tulajdonos)

  const CommentCard({
    super.key,
    required this.commentId,
    required this.comment,
    this.showActions = false,
  });

  Future<void> _editComment(BuildContext context, String currentText) async {
    final textController = TextEditingController(text: currentText);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Comment'),
          content: TextField(
            controller: textController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your comment',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true && textController.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('review_comments').doc(commentId).update({
        'text': textController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _deleteComment(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('review_comments').doc(commentId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentUserId = comment['userId'] ?? '';
    final commentText = comment['text'] ?? '';
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(commentUserId).get(),
      builder: (context, commentUserSnapshot) {
        String commentUserName = 'Anonymous';
        
        if (commentUserSnapshot.hasData && commentUserSnapshot.data!.exists && !commentUserSnapshot.hasError) {
          final userData = commentUserSnapshot.data!.data() as Map<String, dynamic>;
          if (userData['accountVisibility'] == 'public' || commentUserId == currentUserId) {
            commentUserName = userData['username'] ?? userData['email']?.split('@').first ?? 'Reader';
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(commentUserName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  // ÚJ: Kebab menü, ha a showActions igaz és a user a tulajdonos
                  if (showActions && currentUserId == commentUserId)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _editComment(context, commentText);
                        } else if (value == 'delete') {
                          await _deleteComment(context);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(commentText, style: const TextStyle(fontSize: 14, color: AppColors.charcoal)),
            ],
          ),
        );
      },
    );
  }
}