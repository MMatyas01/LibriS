// lib/screens/book_details_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';
import '../widgets/book_cover.dart';
import '../widgets/section_header.dart';
import '../widgets/review_card.dart'; // ÚJ IMPORT
import 'review_details_screen.dart';

class BookDetailsScreen extends StatefulWidget {
  final String bookId;
  final Map<String, dynamic> bookData;
  final String? currentStatus;
  final Function(int)? onNavigateToTab; 

  const BookDetailsScreen({
    super.key,
    required this.bookId,
    required this.bookData,
    this.currentStatus,
    this.onNavigateToTab,
  });

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  bool _isAdding = false;
  late String? _status;

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus;
  }

  Future<void> _addToLibrary() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() => _isAdding = true);

    try {
      await FirebaseFirestore.instance.collection('library_entries').add({
        'userId': currentUser.uid,
        'bookId': widget.bookId,
        'status': 'want_to_read',
        'currentPage': 0,
        'progressVisibility': 'private',
        'addedAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _status = 'want_to_read';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to your "Want to read" list!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding book: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.bookData;
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    
    String pubYear = '';
    if (book['publicationYear'] is Timestamp) {
      pubYear = (book['publicationYear'] as Timestamp).toDate().year.toString();
    } else if (book['publicationYear'] != null) {
      pubYear = book['publicationYear'].toString();
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.charcoal),
        title: const Text(
          'Book details',
          style: TextStyle(color: AppColors.charcoal, fontFamily: 'Serif', fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: BookCover(
                    imageUrl: book['coverUrl'],
                    borderRadius: 12,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (book['genre'] ?? 'UNKNOWN GENRE').toString().toUpperCase(),
                        style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        book['title'] ?? 'Unknown Title',
                        style: const TextStyle(fontFamily: 'Serif', fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        book['author'] ?? 'Unknown Author',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('reviews')
                            .where('bookId', isEqualTo: widget.bookId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          double avgRating = 0.0;
                          int count = 0;
                          if (snapshot.hasData) {
                            count = snapshot.data!.docs.length;
                            if (count > 0) {
                              double total = 0;
                              for (var doc in snapshot.data!.docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                total += (data['rating'] ?? 0).toDouble();
                              }
                              avgRating = total / count;
                            }
                          }

                          return Row(
                            children: [
                              Icon(
                                count > 0 ? Icons.star : Icons.star_border, 
                                color: count > 0 ? Colors.orange : Colors.grey, 
                                size: 18
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  count > 0 ? '${avgRating.toStringAsFixed(1)} · $count ${count == 1 ? 'review' : 'reviews'}' : 'None · 0 reviews',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      _buildStatusBadge(),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.03),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Pages', book['pageCount']?.toString() ?? '-'),
                _buildInfoColumn('Published', pubYear.isNotEmpty ? pubYear : '-'),
                _buildInfoColumn('Publisher', book['publisher']?.toString() ?? '-'),
              ],
            ),
            SizedBox(height: screenHeight * 0.04),

            Text(
              book['description'] ?? 'No description available.',
              style: const TextStyle(fontSize: 15, height: 1.5, color: AppColors.charcoal),
            ),
            SizedBox(height: screenHeight * 0.03),

            if (widget.onNavigateToTab != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); 
                      widget.onNavigateToTab!(3); 
                    },
                    icon: const Icon(Icons.forum_outlined, color: AppColors.forest),
                    label: const Text(
                      'Write a review in Community',
                      style: TextStyle(color: AppColors.forest, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.forest),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),

            if (_status == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAdding ? null : _addToLibrary,
                  icon: _isAdding 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.add),
                  label: const Text('Add to Library'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.forest),
                    const SizedBox(width: 8),
                    Text(
                      'In your library · ${_status == 'reading' ? 'Reading' : (_status == 'finished' ? 'Finished' : 'Want to read')}',
                      style: const TextStyle(color: AppColors.forest, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            SizedBox(height: screenHeight * 0.05),

            // REVIEW-K MEGJELENÍTÉSE AZ ÚJ WIDGETTEL
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reviews')
                  .where('bookId', isEqualTo: widget.bookId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.withValues(alpha: 0.1),
                    child: Text(
                      'Error loading reviews: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  );
                }

                int reviewCount = 0;
                if (snapshot.hasData) reviewCount = snapshot.data!.docs.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Reader reviews',
                      actionText: reviewCount > 0 ? 'See all $reviewCount' : null,
                      onActionTap: () {},
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                      const Text(
                        'No reviews yet.',
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                      )
                    else
                      Column(
                        children: snapshot.data!.docs.take(2).map((doc) {
                          final reviewData = doc.data() as Map<String, dynamic>;
                          // ÚJ: ReviewCard használata
                          return ReviewCard(
                            reviewId: doc.id,
                            review: reviewData,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReviewDetailsScreen(reviewId: doc.id),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: screenHeight * 0.05),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (_status == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.sage.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
        child: const Text('Not in your library', style: TextStyle(color: AppColors.forest, fontSize: 12, fontWeight: FontWeight.w600)),
      );
    }

    String statusText = _status == 'reading' ? 'Reading' : (_status == 'finished' ? 'Finished' : 'Want to read');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppColors.sage, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 14, color: AppColors.forest),
          const SizedBox(width: 4),
          Text('In your library · $statusText', style: const TextStyle(color: AppColors.forest, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          SizedBox(
            height: 24, 
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.charcoal), maxLines: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}