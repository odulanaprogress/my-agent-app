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
    if (kIsWeb) {
      _isInitialized = true;
      return; // On web, GoogleSignIn uses signInWithPopup — no init needed
    }

    if (_isInitializing) {
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
    final cleanEmail = email.trim();
    try {
      // First attempt: standard lowercased email with provided password
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: cleanEmail.toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      final code = e.code.toLowerCase();
      final isCredError = code.contains('invalid-credential') ||
          code.contains('wrong-password') ||
          code.contains('user-not-found');

      // Attempt 2: if password had leading/trailing whitespace and failed, try trimmed password
      if (isCredError && password != password.trim()) {
        try {
          return await _firebaseAuth.signInWithEmailAndPassword(
            email: cleanEmail.toLowerCase(),
            password: password.trim(),
          );
        } catch (_) {}
      }

      // Attempt 3: if email had uppercase characters, try original casing
      if (isCredError && cleanEmail != cleanEmail.toLowerCase()) {
        try {
          return await _firebaseAuth.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
        } catch (_) {}

        if (password != password.trim()) {
          try {
            return await _firebaseAuth.signInWithEmailAndPassword(
              email: cleanEmail,
              password: password.trim(),
            );
          } catch (_) {}
        }
      }

      rethrow;
    }
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String fullName,
    required String role,
    required bool privacyAccepted,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final uid = credential.user!.uid;
    final userProfile = UserModel(
      uid: uid,
      email: normalizedEmail,
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

  // Google Sign-In — uses popup on web, GoogleSignIn plugin on mobile
  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // On web: use Firebase's built-in Google provider popup
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
      } else {
        // On mobile: use the GoogleSignIn plugin
        await _ensureInitialized();
        final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        userCredential = await _firebaseAuth.signInWithCredential(credential);
      }

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
    // Google sign-out can hang on web if user didn't sign in via Google.
    // Always guard it with timeouts and provider checks so Firebase sign-out runs.
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut().timeout(const Duration(seconds: 2));
      } else {
        final isGoogleUser = _firebaseAuth.currentUser?.providerData
            .any((p) => p.providerId == 'google.com') ?? false;
        if (isGoogleUser) {
          await _googleSignIn.signOut().timeout(const Duration(seconds: 2));
        }
      }
    } catch (_) {}

    try {
      await _firebaseAuth.signOut().timeout(const Duration(seconds: 3));
    } catch (_) {}
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
