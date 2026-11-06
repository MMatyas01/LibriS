import 'dart:math';
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

  // Real-time streamek – a Home tabváltás nélkül is frissül
  Stream<Map<String, dynamic>?>? _continueReadingStream;
  Stream<List<Map<String, dynamic>>>? _libraryStream;

  // Popular ajánló marad egyszeri Future (nincs real-time igény)
  Future<Map<String, dynamic>?>? _popularBookFuture;

  @override
  void initState() {
    super.initState();
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _continueReadingStream = _continueReadingSnapshot(currentUser.uid);
      _libraryStream = _librarySnapshot(currentUser.uid);
      _popularBookFuture = _fetchPopularBook();
    }
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

  // --- REAL-TIME: legutóbb olvasott könyv ---
  Stream<Map<String, dynamic>?> _continueReadingSnapshot(String userId) {
    return _firestore
        .collection('library_entries')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'reading')
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return null;

      // Rendezés Dart oldalon: lastReadAt, fallback addedAt, csökkenő
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

  // --- REAL-TIME: teljes library ---
  Stream<List<Map<String, dynamic>>> _librarySnapshot(String userId) {
    return _firestore
        .collection('library_entries')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> results = [];

      for (var doc in snapshot.docs) {
        final entry = doc.data();
        final bookDoc =
            await _firestore.collection('books').doc(entry['bookId']).get();

        if (bookDoc.exists) {
          results.add({
            'entry': entry,
            'book': bookDoc.data(),
          });
        }
      }
      return results;
    });
  }

  Future<Map<String, dynamic>?> _fetchPopularBook() async {
    try {
      final snapshot = await _firestore.collection('books').limit(10).get();
      if (snapshot.docs.isEmpty) return null;
      final randomIndex = Random().nextInt(snapshot.docs.length);
      return snapshot.docs[randomIndex].data();
    } catch (e) {
      debugPrint('Error fetching popular book: $e');
      return null;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _getUserName(User? user) {
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    if (user?.email != null) {
      String emailPrefix = user!.email!.split('@').first;
      return emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
    }
    return 'Reader';
  }

  String _getInitials(User? user) {
    String name = _getUserName(user);
    return name.isNotEmpty ? name[0].toUpperCase() : 'R';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _logout(context));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userName = _getUserName(currentUser);
    final userInitials = _getInitials(currentUser);
    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
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
                        '$greeting, $userName.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      Text(
                        'What will you read today?',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  UserAvatar(initials: userInitials, radius: 24),
                ],
              ),
              const SizedBox(height: 32),

              // --- CONTINUE READING (StreamBuilder) ---
              SectionHeader(
                title: 'Continue reading',
                actionText: 'View all',
                onActionTap: () => widget.onNavigateToTab(1),
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
                          // A stream automatikusan frissül a mentés után,
                          // nincs szükség manuális újratöltésre.
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

              // --- YOUR LIBRARY (StreamBuilder) ---
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

              // --- POPULAR THIS WEEK (Future marad) ---
              SectionHeader(
                title: 'Popular this week',
                actionText: 'Explore',
                onActionTap: () => widget.onNavigateToTab(2),
              ),
              const SizedBox(height: 16),
              FutureBuilder<Map<String, dynamic>?>(
                future: _popularBookFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data == null) {
                    return const Text('No popular books available right now.');
                  }

                  final book = snapshot.data!;
                  final imageUrl = book['coverUrl'];
                  final title = book['title'] ?? 'Unknown Title';
                  final author = book['author'] ?? 'Unknown Author';
                  final description =
                      book['description'] ?? 'No description available.';

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
                                    child: const Icon(Icons.book,
                                        color: AppColors.forest),
                                  );
                                },
                              )
                            : Container(
                                width: 80,
                                height: 120,
                                color: AppColors.sage,
                                child: const Icon(Icons.book,
                                    color: AppColors.forest),
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
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 16),
                                const Text('4.5',
                                    style: TextStyle(fontSize: 14)),
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
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}