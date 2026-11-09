// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import 'login_screen.dart';
import '../widgets/user_avatar.dart';
import '../widgets/section_header.dart';
import '../widgets/book_card_horizontal.dart';
import '../widgets/library_book_card.dart';
import '../widgets/update_progress_sheet.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const HomeScreen({super.key, required this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<Map<String, dynamic>?>? _continueReadingStream;
  Stream<List<Map<String, dynamic>>>? _libraryStream;

  String _username = 'Reader';
  String _initials = 'R';

  @override
  void initState() {
    super.initState();
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _continueReadingStream = _continueReadingSnapshot(currentUser.uid);
      _libraryStream = _librarySnapshot(currentUser.uid);
      _listenToUserProfile(currentUser.uid);
    }
  }

  void _listenToUserProfile(String userId) {
    _firestore.collection('users').doc(userId).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        final fetchedName = data['username'] ?? 'Reader';
        
        setState(() {
          _username = fetchedName;
          _initials = fetchedName.isNotEmpty ? fetchedName[0].toUpperCase() : 'R';
        });
      }
    });
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService().signOut();
    await PreferencesService().clearRememberMe();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Stream<Map<String, dynamic>?> _continueReadingSnapshot(String userId) {
    return _firestore
        .collection('library_entries')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'reading')
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return null;

      final sortedDocs = snapshot.docs.toList()
        ..sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aTime = (aData['lastReadAt'] as Timestamp?)?.toDate() ??
              (aData['addedAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = (bData['lastReadAt'] as Timestamp?)?.toDate() ??
              (bData['addedAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

      final entryDoc = sortedDocs.first;
      final entry = entryDoc.data();
      final bookDoc =
          await _firestore.collection('books').doc(entry['bookId']).get();
      if (!bookDoc.exists) return null;

      return {
        'entryId': entryDoc.id,
        'entry': entry,
        'book': bookDoc.data(),
      };
    });
  }

  // --- MÓDOSÍTOTT: Duplikátumok kiszűrése bookId alapján ---
  Stream<List<Map<String, dynamic>>> _librarySnapshot(String userId) {
    return _firestore
        .collection('library_entries')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      // Map a duplikátumok kiszűréséhez: bookId -> a legjobb entry
      Map<String, Map<String, dynamic>> uniqueBooks = {};

      for (var doc in snapshot.docs) {
        final entry = doc.data();
        final bookId = entry['bookId'] as String;
        final bookDoc = await _firestore.collection('books').doc(bookId).get();

        if (bookDoc.exists) {
          final newEntry = {
            'entry': entry,
            'book': bookDoc.data(),
          };

          if (!uniqueBooks.containsKey(bookId)) {
            uniqueBooks[bookId] = newEntry;
          } else {
            // Prioritás: reading > want_to_read > finished
            int getPriority(String? status) {
              if (status == 'reading') return 3;
              if (status == 'want_to_read') return 2;
              if (status == 'finished') return 1;
              return 0;
            }

            final existingEntry = uniqueBooks[bookId]!['entry'];
            final existingStatus = existingEntry['status'];
            final newStatus = entry['status'];

            if (getPriority(newStatus) > getPriority(existingStatus)) {
              uniqueBooks[bookId] = newEntry;
            } else if (getPriority(newStatus) == getPriority(existingStatus)) {
              // Ha ugyanaz a prioritás, a frissebb lastReadAt nyer
              final existingTime = (existingEntry['lastReadAt'] as Timestamp?)?.toDate() ??
                  (existingEntry['addedAt'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final newTime = (entry['lastReadAt'] as Timestamp?)?.toDate() ??
                  (entry['addedAt'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              if (newTime.isAfter(existingTime)) {
                uniqueBooks[bookId] = newEntry;
              }
            }
          }
        }
      }

      return uniqueBooks.values.toList();
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _logout(context));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LibriS',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$greeting, $_username.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text(
                        'What will you read today?',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  UserAvatar(initials: _initials, radius: 24),
                ],
              ),
              const SizedBox(height: 32),

              const SectionHeader(
                title: 'Continue reading',
              ),
              const SizedBox(height: 16),
              StreamBuilder<Map<String, dynamic>?>(
                stream: _continueReadingStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Text('You are not reading any books currently.');
                  }

                  final data = snapshot.data!;
                  final book = data['book'];
                  final entry = data['entry'];
                  final entryId = data['entryId'];
                  final currentPage = entry['currentPage'] as int? ?? 0;
                  final pageCount = book['pageCount'] as int? ?? 1;
                  final progress = pageCount > 0 ? currentPage / pageCount : 0.0;
                  final bookTitle = book['title'] ?? 'Unknown Title';
                  final coverUrl = book['coverUrl'] as String?;
                  final status = entry['status'] as String? ?? 'reading';

                  return BookCardHorizontal(
                    title: bookTitle,
                    author: book['author'] ?? 'Unknown Author',
                    imageUrl: coverUrl,
                    progressText:
                        '$currentPage/$pageCount pages · ${(progress * 100).toInt()}%',
                    progressValue: progress,
                    backgroundColor: AppColors.sage,
                    textColor: AppColors.charcoal,
                    trailingWidget: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await showUpdateProgressSheet(
                            context: context,
                            entryId: entryId,
                            currentPage: currentPage,
                            totalPages: pageCount,
                            bookTitle: bookTitle,
                            coverUrl: coverUrl,
                            currentStatus: status,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.forest,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: const Text('Resume reading'),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              SectionHeader(
                title: 'Your library',
                actionText: 'View all',
                onActionTap: () => widget.onNavigateToTab(1),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _libraryStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('Your library is empty.');
                  }

                  final libraryData = snapshot.data!;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: libraryData.map((data) {
                        final book = data['book'];
                        final entry = data['entry'];

                        String statusText = entry['status']
                                ?.toString()
                                .replaceAll('_', ' ')
                                .split(' ')
                                .map((word) => word.isNotEmpty
                                    ? '${word[0].toUpperCase()}${word.substring(1)}'
                                    : '')
                                .join(' ') ??
                            'Unknown';

                        return Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: LibraryBookCard(
                            title: book['title'] ?? 'Unknown Title',
                            author: book['author'] ?? 'Unknown Author',
                            status: statusText,
                            imageUrl: book['coverUrl'],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              SectionHeader(
                title: 'Popular this week',
                actionText: 'Explore',
                onActionTap: () => widget.onNavigateToTab(2),
              ),
              const SizedBox(height: 16),
              
              StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('reviews').snapshots(),
                builder: (context, reviewsSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('review_comments').snapshots(),
                    builder: (context, commentsSnapshot) {
                      if (reviewsSnapshot.connectionState == ConnectionState.waiting || 
                          commentsSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
                      Map<String, int> activityMap = {};

                      if (reviewsSnapshot.hasData) {
                        for (var doc in reviewsSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                          if (createdAt != null && createdAt.isAfter(oneWeekAgo)) {
                            final bookId = data['bookId'];
                            if (bookId != null) {
                              activityMap[bookId] = (activityMap[bookId] ?? 0) + 1;
                            }
                          }
                        }
                      }

                      if (commentsSnapshot.hasData && reviewsSnapshot.hasData) {
                        Map<String, String> reviewToBook = {};
                        for (var doc in reviewsSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          reviewToBook[doc.id] = data['bookId'];
                        }

                        for (var doc in commentsSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                          if (createdAt != null && createdAt.isAfter(oneWeekAgo)) {
                            final reviewId = data['reviewId'];
                            final bookId = reviewToBook[reviewId];
                            if (bookId != null) {
                              activityMap[bookId] = (activityMap[bookId] ?? 0) + 1;
                            }
                          }
                        }
                      }

                      String? popularBookId;
                      int maxActivity = 0;
                      activityMap.forEach((bookId, count) {
                        if (count > maxActivity) {
                          maxActivity = count;
                          popularBookId = bookId;
                        }
                      });

                      if (popularBookId == null) {
                        return const Text('No popular books this week.');
                      }

                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('books').doc(popularBookId).get(),
                        builder: (context, bookSnapshot) {
                          if (bookSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!bookSnapshot.hasData || !bookSnapshot.data!.exists) {
                            return const Text('No popular books available right now.');
                          }

                          final book = bookSnapshot.data!.data() as Map<String, dynamic>;
                          
                          double avgRating = 0.0;
                          int reviewCount = 0;
                          if (reviewsSnapshot.hasData) {
                            double total = 0;
                            for (var doc in reviewsSnapshot.data!.docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              if (data['bookId'] == popularBookId) {
                                total += (data['rating'] ?? 0).toDouble();
                                reviewCount++;
                              }
                            }
                            if (reviewCount > 0) {
                              avgRating = total / reviewCount;
                            }
                          }

                          final imageUrl = book['coverUrl'];
                          final title = book['title'] ?? 'Unknown Title';
                          final author = book['author'] ?? 'Unknown Author';
                          final description = book['description'] ?? 'No description available.';

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrl != null && imageUrl.toString().isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        width: 80,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 80,
                                            height: 120,
                                            color: AppColors.sage,
                                            child: const Icon(Icons.book, color: AppColors.forest),
                                          );
                                        },
                                      )
                                    : Container(
                                        width: 80,
                                        height: 120,
                                        color: AppColors.sage,
                                        child: const Icon(Icons.book, color: AppColors.forest),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: theme.textTheme.titleMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            author,
                                            style: theme.textTheme.bodyMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          reviewCount > 0 ? Icons.star : Icons.star_border, 
                                          color: reviewCount > 0 ? Colors.amber : Colors.grey, 
                                          size: 16
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          reviewCount > 0 ? avgRating.toStringAsFixed(1) : 'None',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      description,
                                      style: theme.textTheme.bodyMedium,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}