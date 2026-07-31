import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../shared/models/user_model.dart';

class FirebaseAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ CORRECT: Use the singleton instance (NO constructor)
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _isInitialized = false;
  bool _isInitializing = false;

  User? get currentUser => _firebaseAuth.currentUser;
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    if (_isInitializing) {
      // Wait for the current init attempt to finish.
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isInitializing = true;
    try {
      await _googleSignIn.initialize(
        clientId:
            '752415718905-46n420cu1l4tg5abdnqmjh9f6vhk220q.apps.googleusercontent.com',
        serverClientId:
            '752415718905-s5i5ua81sjsigmg31cgq0j98ud6at8c9.apps.googleusercontent.com',
      );
      _isInitialized = true;
    } finally {
      _isInitializing = false;
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    // All users — including admin and customer support — sign in the same way.
    // Role-based routing is handled by reading `users/{uid}.role` from Firestore
    // after authentication. Hardcoded credentials MUST NOT exist in client code.
    return await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password.trim(),
    );
  }


  Future<UserCredential> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
    required bool privacyAccepted,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final uid = credential.user!.uid;
    final userProfile = UserModel(
      uid: uid,
      email: email.trim(),
      fullName: fullName.trim(),
      role: role,
      isVerified: false,
      privacyAccepted: privacyAccepted,
      onboardingCompleted: false,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(uid).set(userProfile.toMap());
    return credential;
  }

  // ✅ CORRECT implementation for google_sign_in 7.2.0
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Avoid multiple init() calls at runtime.
      await _ensureInitialized();

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // ✅ CORRECT: authentication is a getter
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // ✅ CORRECT: Only idToken exists in 7.2.0 (NO accessToken!)
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        // accessToken does NOT exist in 7.2.0 - DO NOT include it!
      );

      final UserCredential userCredential = await _firebaseAuth
          .signInWithCredential(credential);

      // Create Firestore user document if new user
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        final userProfile = UserModel(
          uid: userCredential.user!.uid,
          email: userCredential.user!.email ?? '',
          fullName: userCredential.user!.displayName ?? '',
          role: 'user',
          isVerified: userCredential.user!.emailVerified,
          privacyAccepted: true,
          onboardingCompleted: false,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userProfile.toMap());
      }

      return userCredential;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      throw FirebaseAuthException(
        code: 'google-signin-failed',
        message: 'Google Sign-In failed: ${e.toString()}',
      );
    }
  }

  Future<void> signOut() async {
    // Google sign-out may throw if the user signed in with email/password
    // or if the GoogleSignIn plugin was never initialised. Always guard it
    // so Firebase sign-out is guaranteed to run.
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    await _firebaseAuth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
}
