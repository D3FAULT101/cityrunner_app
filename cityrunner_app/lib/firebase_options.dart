// Generated configuration is intentionally not committed. Run `flutterfire
// configure` for the CityRunner Firebase project to replace this file with the
// generated version, or pass the values below using --dart-define.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const _authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

  static bool get isConfigured =>
      _apiKey.isNotEmpty && _appId.isNotEmpty && _projectId.isNotEmpty && _messagingSenderId.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw StateError(
        'Firebase is not configured. Run flutterfire configure or provide the FIREBASE_* dart-defines.',
      );
    }
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      authDomain: kIsWeb && _authDomain.isNotEmpty ? _authDomain : null,
    );
  }
}
