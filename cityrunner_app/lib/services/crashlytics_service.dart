import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'firebase_bootstrap.dart';

class CrashlyticsService {
  CrashlyticsService._();

  static final instance = CrashlyticsService._();

  Future<void> recordError(Object error, StackTrace stackTrace, {bool fatal = false}) async {
    if (!FirebaseBootstrap.isReady) return;
    await FirebaseCrashlytics.instance.recordError(error, stackTrace, fatal: fatal);
  }

  Future<void> setUser(String userId, {String? role}) async {
    if (!FirebaseBootstrap.isReady) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    if (role != null) await FirebaseCrashlytics.instance.setCustomKey('role', role);
  }

  Future<void> clearUser() async {
    if (!FirebaseBootstrap.isReady) return;
    await FirebaseCrashlytics.instance.setUserIdentifier('');
  }
}
