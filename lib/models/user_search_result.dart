import 'package:cloud_firestore/cloud_firestore.dart';

class UserSearchResult {
  const UserSearchResult({
    required this.id,
    required this.username,
    required this.profileImage,
  });

  final String id;
  final String username;
  final String profileImage;

  factory UserSearchResult.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data =
        document.data() ?? <String, dynamic>{};

    return UserSearchResult(
      id: document.id,
      username:
          (data['username'] as String? ?? '').trim(),
      profileImage:
          (data['profileImage'] as String? ?? '').trim(),
    );
  }
}