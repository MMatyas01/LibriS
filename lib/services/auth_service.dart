import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges {
    return _firebaseAuth.authStateChanges();
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail({
  required String email,
}) {
  return _firebaseAuth.sendPasswordResetEmail(
    email: email.trim(),
  );
}

Future<UserCredential> register({
  required String email,
  required String password,
}) {
  return _firebaseAuth.createUserWithEmailAndPassword(
    email: email.trim(),
    password: password,
  );
}

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}