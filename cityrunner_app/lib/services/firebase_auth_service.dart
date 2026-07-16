import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'firebase_bootstrap.dart';

class FirebaseAuthService {
  FirebaseAuthService._();

  static final instance = FirebaseAuthService._();

  String? _verificationId;
  ConfirmationResult? _webConfirmation;

  Future<void> requestPhoneOtp(String phoneNumber) async {
    _requireReady();
    if (kIsWeb) {
      _webConfirmation = await FirebaseAuth.instance.signInWithPhoneNumber(phoneNumber);
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (error) => throw StateError(error.message ?? 'Phone verification failed.'),
      codeSent: (verificationId, _) => _verificationId = verificationId,
      codeAutoRetrievalTimeout: (verificationId) => _verificationId ??= verificationId,
      timeout: const Duration(seconds: 60),
    );
  }

  Future<String> confirmPhoneOtp(String code) async {
    _requireReady();
    if (kIsWeb) {
      final confirmation = _webConfirmation;
      if (confirmation == null) throw StateError('Request a new verification code.');
      await confirmation.confirm(code);
    } else if (_verificationId != null) {
      final credential = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: code);
      await FirebaseAuth.instance.signInWithCredential(credential);
    }
    return _currentIdToken();
  }

  Future<String> signInWithEmailPassword(String email, String password) async {
    _requireReady();
    await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    return _currentIdToken();
  }

  Future<String> signInWithGoogle() async {
    _requireReady();
    if (kIsWeb) {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      return _currentIdToken();
    }
    final account = await GoogleSignIn().signIn();
    if (account == null) throw StateError('Google sign-in was cancelled.');
    final authentication = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: authentication.accessToken,
      idToken: authentication.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
    return _currentIdToken();
  }

  Future<String> signInWithApple() async {
    _requireReady();
    final rawNonce = _nonce();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email],
      nonce: sha256.convert(rawNonce.codeUnits).toString(),
    );
    final identityToken = appleCredential.identityToken;
    if (identityToken == null) throw StateError('Apple did not return an identity token.');
    final credential = OAuthProvider('apple.com').credential(idToken: identityToken, rawNonce: rawNonce);
    await FirebaseAuth.instance.signInWithCredential(credential);
    return _currentIdToken();
  }

  Future<String?> appCheckToken() async => FirebaseBootstrap.isReady ? null : null;

  Future<void> signOut() async {
    if (!FirebaseBootstrap.isReady) return;
    await FirebaseAuth.instance.signOut();
    _verificationId = null;
    _webConfirmation = null;
  }

  Future<String> _currentIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Firebase sign-in did not complete.');
    final token = await user.getIdToken();
    if (token == null) throw StateError('Could not obtain a Firebase ID token.');
    return token;
  }

  void _requireReady() {
    if (!FirebaseBootstrap.isReady) {
      throw StateError('Firebase is not configured for this build.');
    }
  }

  String _nonce([int length = 32]) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List<String>.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
