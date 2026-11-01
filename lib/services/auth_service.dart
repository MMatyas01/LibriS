import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Akkor dobjuk, ha a bejelentkezés helyes volt, de az e-mail nincs megerősítve.
class EmailNotVerifiedException implements Exception {
  final String message;
  EmailNotVerifiedException([
    this.message =
        'Your email address has not been verified yet. Please check your inbox.',
  ]);
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // ÚJ

  // A napló alapján a tesztfelhasználó megkerüli az ellenőrzést
  static const String _testUserEmail = 'teszt@libris.hu';

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges {
    return _firebaseAuth.authStateChanges();
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) return credential;

    // Tesztfelhasználó megkerüli az ellenőrzést
    if (user.email != null && user.email!.toLowerCase() == _testUserEmail) {
      return credential;
    }

    // Fontos: a emailVerified állapot csak reload() után frissül
    await user.reload();
    final refreshedUser = _firebaseAuth.currentUser;

    if (refreshedUser == null || !refreshedUser.emailVerified) {
      await _firebaseAuth.signOut();
      throw EmailNotVerifiedException();
    }

    return credential;
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    // 1. Firebase Auth fiók létrehozása
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;

    if (user != null) {
      // 2. Firestore mentés (a képernyőkép alapján)
      await _firestore.collection('users').doc(user.uid).set({
        'email': email.trim(),
        'username': email.split('@').first, // Alapértelmezett név az e-mailből
        'profileImage': '',
        'accountVisibility': 'public',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Verifikációs e-mail kiküldése
      await user.sendEmailVerification();
    }

    return credential;
  }

  Future<void> sendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user to send a verification email to.');
    }
    await user.sendEmailVerification();
  }

  Future<void> sendPasswordResetEmail({
    required String email,
  }) {
    return _firebaseAuth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}
