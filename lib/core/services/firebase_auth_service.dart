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
