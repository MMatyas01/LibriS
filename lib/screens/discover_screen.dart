import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';
import '../widgets/search_bar.dart';
import '../widgets/book_card_horizontal.dart';
import 'book_details_screen.dart';

class DiscoverScreen extends StatefulWidget {
  final Function(int) onNavigateToTab; // ÚJ

  const DiscoverScreen({super.key, required this.onNavigateToTab}); // ÚJ

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _searchQuery = '';
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verticalGap = MediaQuery.sizeOf(context).height * 0.02;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Serif',
                    ),
                  ),
                  SizedBox(height: verticalGap / 2),
                  const Text(
                    'Find your next chapter.',
                    style: TextStyle(color: AppColors.charcoal, fontSize: 16),
                  ),
                ],
              ),
            ),
            SizedBox(height: verticalGap),

            // 2. Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SearchBarWidget(
                hintText: 'Search by title or author...',
                trailingIcon: null, 
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            SizedBox(height: verticalGap * 1.5),

            // 3. Results Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _searchQuery.isEmpty
                    ? 'ALL BOOKS'
                    : 'RESULTS FOR "$_searchQuery"'.toUpperCase(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: verticalGap / 2),

            // 4. Book List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('books').snapshots(),
                builder: (context, booksSnapshot) {
                  if (booksSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!booksSnapshot.hasData || booksSnapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No books found.'));
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('reviews').snapshots(),
                    builder: (context, reviewsSnapshot) {
                      Map<String, Map<String, dynamic>> bookStats = {};
                      if (reviewsSnapshot.hasData) {
                        for (var doc in reviewsSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final bookId = data['bookId'];
                          if (bookId != null) {
                            final rating = (data['rating'] ?? 0).toDouble();
                            if (!bookStats.containsKey(bookId)) {
                              bookStats[bookId] = {'total': 0.0, 'count': 0};
                            }
                            bookStats[bookId]!['total'] += rating;
                            bookStats[bookId]!['count'] += 1;
                          }
                        }
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('library_entries')
                            .where('userId', isEqualTo: _userId)
                            .snapshots(),
                        builder: (context, librarySnapshot) {
                          Map<String, String> userLibraryStatus = {};
                          if (librarySnapshot.hasData) {
                            for (var doc in librarySnapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              userLibraryStatus[data['bookId']] = data['status'];
                            }
                          }

                          List<QueryDocumentSnapshot> allBooks = booksSnapshot.data!.docs;
                          List<QueryDocumentSnapshot> filteredBooks = allBooks.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final title = (data['title'] ?? '').toString().toLowerCase();
                            final author = (data['author'] ?? '').toString().toLowerCase();

                            if (_searchQuery.isEmpty) return true;
                            return title.contains(_searchQuery) || author.contains(_searchQuery);
                          }).toList();

                          if (filteredBooks.isEmpty) {
                            return const Center(child: Text('No matching books found.'));
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: filteredBooks.length,
                            separatorBuilder: (context, index) => SizedBox(height: verticalGap),
                            itemBuilder: (context, index) {
                              final bookDoc = filteredBooks[index];
                              final bookData = bookDoc.data() as Map<String, dynamic>;
                              final status = userLibraryStatus[bookDoc.id];
                              
                              final stats = bookStats[bookDoc.id];
                              final double avgRating = stats != null ? (stats['total'] / stats['count']) : 0.0;
                              final int reviewCount = stats != null ? stats['count'] : 0;

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BookDetailsScreen(
                                        bookId: bookDoc.id,
                                        bookData: bookData,
                                        currentStatus: status,
                                        onNavigateToTab: widget.onNavigateToTab, // ÁTADVA
                                      ),
                                    ),
                                  );
                                },
                                child: BookCardHorizontal(
                                  title: bookData['title'] ?? 'Unknown Title',
                                  author: bookData['author'] ?? 'Unknown Author',
                                  imageUrl: bookData['coverUrl'],
                                  backgroundColor: Colors.white,
                                  textColor: AppColors.charcoal,
                                  trailingWidget: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildStatusBadge(status),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(
                                            reviewCount > 0 ? Icons.star : Icons.star_border, 
                                            color: reviewCount > 0 ? Colors.orange : Colors.grey, 
                                            size: 16
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            reviewCount > 0 ? avgRating.toStringAsFixed(1) : 'None',
                                            style: TextStyle(
                                              color: reviewCount > 0 ? Colors.grey[700] : Colors.grey, 
                                              fontSize: 13, 
                                              fontWeight: FontWeight.bold
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('View book details ', style: TextStyle(color: AppColors.forest, fontSize: 13, fontWeight: FontWeight.w600)),
                                          const Icon(Icons.arrow_forward, color: AppColors.forest, size: 14),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    if (status == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.sage.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Not in your library',
          style: TextStyle(color: AppColors.forest, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      );
    }

    String statusText = status == 'reading' ? 'Reading' : (status == 'finished' ? 'Finished' : 'Want to read');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 12, color: AppColors.forest),
          const SizedBox(width: 4),
          Text(
            'In your library · $statusText',
            style: const TextStyle(color: AppColors.forest, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}