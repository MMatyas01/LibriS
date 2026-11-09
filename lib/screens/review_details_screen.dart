// lib/screens/review_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';
import '../widgets/comment_card.dart'; // ÚJ IMPORT

class ReviewDetailsScreen extends StatefulWidget {
  final String reviewId;

  const ReviewDetailsScreen({super.key, required this.reviewId});

  @override
  State<ReviewDetailsScreen> createState() => _ReviewDetailsScreenState();
}

class _ReviewDetailsScreenState extends State<ReviewDetailsScreen> {
  Future<void> _toggleLikeReview(bool isCurrentlyLiked) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final accountVisibility = userDoc.data()?['accountVisibility'] ?? 'private';

    if (accountVisibility == 'private') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You can't use this feature, your account is private."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final reviewRef = FirebaseFirestore.instance.collection('reviews').doc(widget.reviewId);

    try {
      if (isCurrentlyLiked) {
        await reviewRef.update({
          'likedBy': FieldValue.arrayRemove([currentUser.uid]),
        });
      } else {
        await reviewRef.update({
          'likedBy': FieldValue.arrayUnion([currentUser.uid]),
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
        title: const Text(
          'Review',
          style: TextStyle(color: AppColors.charcoal, fontFamily: 'Serif', fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('reviews').doc(widget.reviewId).snapshots(),
        builder: (context, reviewSnapshot) {
          if (reviewSnapshot.hasError) {
            return Center(child: Text('Error: ${reviewSnapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (reviewSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!reviewSnapshot.hasData || !reviewSnapshot.data!.exists) {
            return const Center(child: Text('Review not found.'));
          }

          final review = reviewSnapshot.data!.data() as Map<String, dynamic>;
          final userId = review['userId'] ?? '';
          final rating = (review['rating'] ?? 0) as int;
          final title = review['reviewTitle'] ?? '';
          final body = review['reviewBody'] ?? review['text'] ?? 'No review text provided.';
          final List likedBy = review['likedBy'] ?? [];
          final likesCount = likedBy.length;
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          final isLiked = currentUserId != null && likedBy.contains(currentUserId);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FŐ REVIEW FEJLÉCE
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                  builder: (context, userSnapshot) {
                    String userName = 'Anonymous Reader';
                    String initials = 'AR';

                    if (userSnapshot.hasData && userSnapshot.data!.exists && !userSnapshot.hasError) {
                      final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      if (userData['accountVisibility'] == 'public' || userId == currentUserId) {
                        userName = userData['username'] ?? userData['email']?.split('@').first ?? 'Reader';
                        final nameParts = userName.trim().split(' ');
                        if (nameParts.isNotEmpty) {
                          initials = nameParts.length > 1 ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase() : nameParts[0][0].toUpperCase();
                        }
                      }
                    }

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.sage,
                          child: Text(initials, style: const TextStyle(color: AppColors.forest, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            return Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.orange, size: 18);
                          }),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (title.isNotEmpty) ...[
                  Text(title, style: const TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 22, color: AppColors.charcoal)),
                  const SizedBox(height: 8),
                ],
                Text(body, style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.charcoal)),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleLikeReview(isLiked),
                      child: Row(
                        children: [
                          Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey[600], size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '$likesCount likes',
                            style: TextStyle(color: isLiked ? Colors.red : Colors.grey[600], fontWeight: isLiked ? FontWeight.bold : FontWeight.normal),
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('review_comments').where('reviewId', isEqualTo: widget.reviewId).snapshots(),
                      builder: (context, commentsSnapshot) {
                        if (commentsSnapshot.hasError) {
                           return Text(' · Error loading comments', style: TextStyle(color: Colors.red[300]));
                        }
                        int commentsCount = 0;
                        if (commentsSnapshot.hasData) commentsCount = commentsSnapshot.data!.docs.length;
                        return Text(' · $commentsCount comments', style: TextStyle(color: Colors.grey[600]));
                      },
                    ),
                  ],
                ),
                const Divider(height: 40),

                const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Serif', color: AppColors.charcoal)),
                const SizedBox(height: 16),

                // HOZZÁSZÓLÁSOK AZ ÚJ WIDGETTEL
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('review_comments')
                      .where('reviewId', isEqualTo: widget.reviewId)
                      .orderBy('createdAt', descending: false)
                      .snapshots(),
                  builder: (context, commentsSnapshot) {
                    if (commentsSnapshot.hasError) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.red.withValues(alpha: 0.1),
                        child: Text(
                          'Error loading comments: ${commentsSnapshot.error}',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      );
                    }

                    if (commentsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!commentsSnapshot.hasData || commentsSnapshot.data!.docs.isEmpty) {
                      return const Text('No comments yet.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: commentsSnapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = commentsSnapshot.data!.docs[index];
                        final commentData = doc.data() as Map<String, dynamic>;
                        
                        // ÚJ: CommentCard használata
                        return CommentCard(
                          commentId: doc.id,
                          comment: commentData,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}