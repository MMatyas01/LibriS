// lib/screens/my_library_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_colors.dart';
import '../widgets/book_card_horizontal.dart';
import '../widgets/update_progress_sheet.dart';

class MyLibraryScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const MyLibraryScreen({super.key, required this.onNavigateToTab});

  @override
  State<MyLibraryScreen> createState() => _MyLibraryScreenState();
}

class _MyLibraryScreenState extends State<MyLibraryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _selectedTabIndex = 0;
  final List<String> _tabs = ['Reading', 'Want to read', 'Finished'];
  final List<String> _statuses = ['reading', 'want_to_read', 'finished'];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLoading = true;
  List<Map<String, dynamic>> _allLibraryData = [];

  int _readingGoal = 12;
  
  // ÚJ: Stream feliratkozás a valós idejű frissítéshez
  StreamSubscription? _librarySubscription;

  @override
  void initState() {
    super.initState();
    _listenToLibraryData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _librarySubscription?.cancel(); // Leiratkozás a memóriaszivárgás elkerüléséhez
    _searchController.dispose();
    super.dispose();
  }

  void _listenToLibraryData() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Cél (readingGoal) lekérése a users kollekcióból (egyszeri)
    _firestore.collection('users').doc(currentUser.uid).get().then((userDoc) {
      if (userDoc.exists && mounted) {
        final userData = userDoc.data();
        if (userData != null && userData['readingGoal'] != null) {
          setState(() {
            _readingGoal = userData['readingGoal'] as int;
          });
        }
      }
    });

    // Könyvtár valós idejű figyelése
    _librarySubscription = _firestore
        .collection('library_entries')
        .where('userId', isEqualTo: currentUser.uid)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Map<String, dynamic>> results = [];
          for (var doc in snapshot.docs) {
            final entry = doc.data();
            final bookDoc =
                await _firestore.collection('books').doc(entry['bookId']).get();
            if (bookDoc.exists) {
              results.add({
                'entryId': doc.id,
                'entry': entry,
                'book': bookDoc.data(),
              });
            }
          }
          return results;
        })
        .listen((results) {
          if (mounted) {
            setState(() {
              _allLibraryData = results;
              _isLoading = false;
            });
          }
        });
  }

  String get _searchHintText {
    final currentTab = _tabs[_selectedTabIndex].toLowerCase();
    return 'Search in $currentTab...';
  }

  List<Map<String, dynamic>> get _filteredBooks {
    final currentStatus = _statuses[_selectedTabIndex];

    final filtered = _allLibraryData.where((data) {
      final entry = data['entry'];
      final book = data['book'];

      if (entry['status'] != currentStatus) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = (book['title'] ?? '').toString().toLowerCase();
        final author = (book['author'] ?? '').toString().toLowerCase();

        if (!title.contains(query) && !author.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Csoportosítás a 'finished' szekciónál bookId alapján
    if (currentStatus == 'finished') {
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (var item in filtered) {
        final bookId = item['entry']['bookId'] as String;
        grouped.putIfAbsent(bookId, () => []).add(item);
      }

      final result = <Map<String, dynamic>>[];
      for (var entryList in grouped.values) {
        entryList.sort((a, b) {
          final aData = a['entry'];
          final bData = b['entry'];
          final aTime = (aData['lastReadAt'] as Timestamp?)?.toDate() ??
              (aData['addedAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = (bData['lastReadAt'] as Timestamp?)?.toDate() ??
              (bData['addedAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

        final mainItem = Map<String, dynamic>.from(entryList.first);
        mainItem['readCount'] = entryList.length;
        mainItem['allEntryIds'] =
            entryList.map((e) => e['entryId'] as String).toList();
        result.add(mainItem);
      }
      return result;
    }

    return filtered;
  }

  Future<void> _confirmDelete(List<String> entryIds, String bookTitle) async {
    final isMultiple = entryIds.length > 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove book?'),
        content: Text(
          isMultiple
              ? 'Remove all ${entryIds.length} read entries for "$bookTitle"? This cannot be undone.'
              : 'Remove "$bookTitle" from your library? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = _firestore.batch();
      for (var id in entryIds) {
        batch.delete(_firestore.collection('library_entries').doc(id));
      }
      await batch.commit();

      // A _fetchLibraryData() hívás törölve, mert a Stream automatikusan frissít!
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book removed from library.')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting entry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _confirmReRead() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Read again?'),
        content: const Text('Do you want to read this book again?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _reReadBook({
    required String bookId,
    required String bookTitle,
  }) async {
    final confirmed = await _confirmReRead();
    if (!confirmed) return;

    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _firestore.collection('library_entries').add({
        'userId': currentUser.uid,
        'bookId': bookId,
        'status': 'want_to_read',
        'currentPage': 0,
        'progressVisibility': 'private',
        'addedAt': FieldValue.serverTimestamp(),
        'lastReadAt': FieldValue.serverTimestamp(),
      });
      
      // A _fetchLibraryData() hívás törölve
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to Want to read.')),
        );
      }
    } catch (e) {
      debugPrint('Error re-reading book: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startReading(String entryId) async {
    try {
      await _firestore.collection('library_entries').doc(entryId).update({
        'status': 'reading',
        'currentPage': 0,
        'lastReadAt': FieldValue.serverTimestamp(),
      });
      
      // A _fetchLibraryData() hívás törölve
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Started reading!')),
        );
      }
    } catch (e) {
      debugPrint('Error starting reading: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProgressForBook({
    required String entryId,
    required int currentPage,
    required int pageCount,
    required String bookTitle,
    required String status,
    String? coverUrl,
  }) async {
    final saved = await showUpdateProgressSheet(
      context: context,
      entryId: entryId,
      currentPage: currentPage,
      totalPages: pageCount,
      bookTitle: bookTitle,
      coverUrl: coverUrl,
      currentStatus: status,
    );
    // A _fetchLibraryData() hívás törölve, a sheet bezárásakor a stream már frissített
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filteredBooks = _filteredBooks;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => widget.onNavigateToTab(2),
        icon: const Icon(Icons.add),
        label: const Text('Add book'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Library',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildReadingYearCard(context),
              const SizedBox(height: 24),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_tabs.length, (index) {
                    final isSelected = _selectedTabIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(_tabs[index]),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedTabIndex = index;
                              _searchController.clear();
                            });
                          }
                        },
                        selectedColor: AppColors.forest,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.charcoal,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.forest
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _searchHintText,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'ON YOUR NIGHTSTAND',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),

              if (filteredBooks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('No books found here.'),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => widget.onNavigateToTab(2),
                          icon: const Icon(Icons.add),
                          label: const Text('Add a book'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredBooks.length,
                  itemBuilder: (context, index) {
                    final data = filteredBooks[index];
                    final book = data['book'];
                    final entry = data['entry'];
                    final entryId = data['entryId'] as String;
                    final status = entry['status'] as String? ?? 'reading';
                    final bookId = entry['bookId'] as String;

                    final readCount = data['readCount'] as int?;
                    final allEntryIds =
                        (data['allEntryIds'] as List<String>?) ?? [entryId];

                    final currentPage = entry['currentPage'] as int? ?? 0;
                    final pageCount = book['pageCount'] as int? ?? 1;
                    final progress =
                        pageCount > 0 ? currentPage / pageCount : 0.0;

                    final bookTitle = book['title'] ?? 'Unknown Title';
                    final coverUrl = book['coverUrl'] as String?;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: BookCardHorizontal(
                        title: bookTitle,
                        author: book['author'] ?? 'Unknown Author',
                        imageUrl: coverUrl,
                        description: book['description'],
                        readCount: readCount,
                        progressText: status == 'reading'
                            ? '$currentPage/$pageCount pages · ${(progress * 100).toInt()}%'
                            : null,
                        progressValue: status == 'reading' ? progress : null,
                        backgroundColor: AppColors.sage,
                        textColor: AppColors.charcoal,
                        trailingWidget: _buildTrailingActions(
                          status: status,
                          entryId: entryId,
                          currentPage: currentPage,
                          pageCount: pageCount,
                          bookTitle: bookTitle,
                          coverUrl: coverUrl,
                        ),
                        topRightWidget: _buildKebabMenu(
                          entryIds: allEntryIds,
                          bookId: bookId,
                          bookTitle: bookTitle,
                          status: status,
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildTrailingActions({
    required String status,
    required String entryId,
    required int currentPage,
    required int pageCount,
    required String bookTitle,
    String? coverUrl,
  }) {
    if (status == 'reading') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _updateProgressForBook(
            entryId: entryId,
            currentPage: currentPage,
            pageCount: pageCount,
            bookTitle: bookTitle,
            status: status,
            coverUrl: coverUrl,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.forest,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Update progress'),
        ),
      );
    }

    if (status == 'want_to_read') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _startReading(entryId),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.forest,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Start reading'),
        ),
      );
    }

    return null;
  }

  Widget _buildKebabMenu({
    required List<String> entryIds,
    required String bookId,
    required String bookTitle,
    required String status,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: AppColors.charcoal,
        size: 22,
      ),
      padding: EdgeInsets.zero,
      tooltip: 'More options',
      onSelected: (value) {
        if (value == 'delete') {
          _confirmDelete(entryIds, bookTitle);
        } else if (value == 'reread') {
          _reReadBook(bookId: bookId, bookTitle: bookTitle);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete'),
        ),
        if (status == 'finished')
          const PopupMenuItem<String>(
            value: 'reread',
            child: Text('Re-read'),
          ),
      ],
    );
  }

  Widget _buildReadingYearCard(BuildContext context) {
    final finishedCount = _allLibraryData
        .where((data) => data['entry']['status'] == 'finished')
        .length;

    final goalProgress =
        _readingGoal > 0 ? (finishedCount / _readingGoal).clamp(0.0, 1.0) : 0.0;

    final remainingBooks = _readingGoal - finishedCount;
    final currentYear = DateTime.now().year;

    String goalMessage;
    if (remainingBooks > 0) {
      goalMessage =
          '$remainingBooks more ${remainingBooks == 1 ? 'book' : 'books'} to reach your $currentYear goal';
    } else {
      goalMessage = 'You reached your $currentYear goal! Amazing work.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YOUR READING YEAR',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Icon(Icons.menu_book_outlined, color: Colors.white, size: 48),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$finishedCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' / $_readingGoal',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'books finished.',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "You're making room for stories.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: goalProgress,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 12),
          Text(
            goalMessage,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}