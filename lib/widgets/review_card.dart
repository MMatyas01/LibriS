// lib/widgets/review_card.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class ReviewCard extends StatefulWidget {
  final String reviewId;
  final Map<String, dynamic> review;
  final VoidCallback onTap;
  final bool showBookTitle;
  final String? bookTitle;
  final bool showActions; // ÚJ: Ha igaz, megjelenik a kebab menü (ha a user a tulajdonos)

  const ReviewCard({
    super.key,
    required this.reviewId,
    required this.review,
    required this.onTap,
    this.showBookTitle = false,
    this.bookTitle,
    this.showActions = false,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  Future<void> _toggleLike() async {
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
    final List likedBy = widget.review['likedBy'] ?? [];
    final isCurrentlyLiked = likedBy.contains(currentUser.uid);

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

  Future<void> _editReview(int currentRating, String currentText) async {
    int selectedRating = currentRating;
    final textController = TextEditingController(text: currentText);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Review'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rating'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedRating ? Icons.star : Icons.star_border,
                            color: Colors.orange,
                          ),
                          onPressed: () {
                            setStateDialog(() {
                              selectedRating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Your review',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
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
      },
    );

    if (result == true && textController.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('reviews').doc(widget.reviewId).update({
        'rating': selectedRating,
        'text': textController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _deleteReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review? This will also delete all its comments.'),
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
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(FirebaseFirestore.instance.collection('reviews').doc(widget.reviewId));
      
      final comments = await FirebaseFirestore.instance
          .collection('review_comments')
          .where('reviewId', isEqualTo: widget.reviewId)
          .get();
      
      for (var doc in comments.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final userId = review['userId'] ?? '';
    final rating = (review['rating'] ?? 0) as int;
    final title = review['reviewTitle'] ?? '';
    final body = review['reviewBody'] ?? review['text'] ?? 'No review text provided.';
    final List likedBy = review['likedBy'] ?? [];
    final likesCount = likedBy.length;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isLiked = currentUserId != null && likedBy.contains(currentUserId);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showBookTitle && widget.bookTitle != null) ...[
              Text(
                widget.bookTitle!,
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],
            
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
                      initials = nameParts.length > 1 
                          ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase() 
                          : nameParts[0][0].toUpperCase();
                    }
                  }
                }

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.sage,
                      child: Text(initials, style: const TextStyle(color: AppColors.forest, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                    ),
                    // ÚJ: Kebab menü, ha a showActions igaz és a user a tulajdonos
                    if (widget.showActions && currentUserId == userId)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            await _editReview(rating, body);
                          } else if (value == 'delete') {
                            await _deleteReview();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        return Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.orange, size: 14);
                      }),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (title.isNotEmpty) ...[
              Text(title, style: const TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
            ],
            Text(body, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 12),
            
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey[600], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$likesCount likes',
                        style: TextStyle(
                          color: isLiked ? Colors.red : Colors.grey[600], 
                          fontSize: 12, 
                          fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('review_comments').where('reviewId', isEqualTo: widget.reviewId).snapshots(),
                  builder: (context, commentsSnapshot) {
                    if (commentsSnapshot.hasError) {
                      return Text(' · Error loading comments', style: TextStyle(color: Colors.red[300], fontSize: 12));
                    }
                    int commentsCount = 0;
                    if (commentsSnapshot.hasData) commentsCount = commentsSnapshot.data!.docs.length;
                    return Text(' · $commentsCount comments · ', style: TextStyle(color: Colors.grey[600], fontSize: 12));
                  },
                ),
                
                const Text('Read review ', style: TextStyle(color: AppColors.forest, fontSize: 12, fontWeight: FontWeight.bold)),
                const Icon(Icons.arrow_forward, color: AppColors.forest, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}