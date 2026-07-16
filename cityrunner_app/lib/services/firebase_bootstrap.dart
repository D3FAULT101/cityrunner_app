import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Owns process-wide Firebase startup. All feature services check [isReady]
/// before touching Firebase, which keeps local backend-only development usable.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _isReady = false;

  static bool get isReady => _isReady;

  static Future<bool> initialize() async {
    if (_isReady) return true;
    if (!DefaultFirebaseOptions.isConfigured) return false;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    _isReady = true;
    await _activateAppCheck();
    return true;
  }

  static Future<void> _activateAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
        webProvider: ReCaptchaV3Provider(
          const String.fromEnvironment('FIREBASE_APP_CHECK_RECAPTCHA_SITE_KEY'),
        ),
      );
    } catch (_) {
      // App Check is enforced from the Firebase console only after debug tokens
      // and production providers have been registered for every platform.
    }
  }
}
