import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_search_result.dart';

class UserSearchService {
  UserSearchService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : _firestore =
            firestore ?? FirebaseFirestore.instance,
        _firebaseAuth =
            firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Future<List<UserSearchResult>> searchByUsername(
    String username,
  ) async {
    final String query = username.trim();

    if (query.length < 3) {
      return <UserSearchResult>[];
    }

    final String? currentUserId =
        _firebaseAuth.currentUser?.uid;

    if (currentUserId == null) {
      throw StateError(
        'You must be logged in to search for readers.',
      );
    }

    final QuerySnapshot<Map<String, dynamic>>
        snapshot = await _firestore
            .collection('users')
            .where(
              'username',
              isEqualTo: query,
            )
            .where(
              'accountVisibility',
              isEqualTo: 'public',
            )
            .limit(10)
            .get();

    return snapshot.docs
        .where(
          (
            QueryDocumentSnapshot<
                Map<String, dynamic>> document,
          ) =>
              document.id != currentUserId,
        )
        .map(
          UserSearchResult.fromFirestore,
        )
        .toList();
  }
}