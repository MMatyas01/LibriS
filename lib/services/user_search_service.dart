import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_search_result.dart';

class UserSearchService {
  UserSearchService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Future<List<UserSearchResult>> searchByUsername(
    String username,
  ) async {
    final String normalizedQuery = username.trim().toLowerCase();

    if (normalizedQuery.length < 2) {
      return <UserSearchResult>[];
    }

    final String? currentUserId = _firebaseAuth.currentUser?.uid;

    if (currentUserId == null) {
      throw StateError(
        'You must be logged in to search for readers.',
      );
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _firestore
            .collection('users')
            .where('accountVisibility', isEqualTo: 'public')
            .limit(100)
            .get();

    final List<UserSearchResult> matches = snapshot.docs
        .where((document) {
          if (document.id == currentUserId) {
            return false;
          }

          final String storedUsername =
              (document.data()['username'] as String? ?? '')
                  .trim()
                  .toLowerCase();

          return storedUsername.startsWith(normalizedQuery);
        })
        .map(UserSearchResult.fromFirestore)
        .toList()
      ..sort(
        (first, second) => first.username
            .toLowerCase()
            .compareTo(second.username.toLowerCase()),
      );

    return matches.take(10).toList();
  }
}
