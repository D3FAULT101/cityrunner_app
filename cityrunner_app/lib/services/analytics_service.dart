import 'package:firebase_analytics/firebase_analytics.dart';

import 'firebase_bootstrap.dart';

class AnalyticsService {
  AnalyticsService._();

  static final instance = AnalyticsService._();

  Future<void> event(String name, {Map<String, Object>? parameters}) async {
    if (!FirebaseBootstrap.isReady) return;
    await FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
  }

  Future<void> screen(String routeName) async {
    if (!FirebaseBootstrap.isReady) return;
    await FirebaseAnalytics.instance.logScreenView(screenName: routeName);
  }

  Future<void> setUser(String userId, {String? role}) async {
    if (!FirebaseBootstrap.isReady) return;
    await FirebaseAnalytics.instance.setUserId(id: userId);
    if (role != null) await FirebaseAnalytics.instance.setUserProperty(name: 'role', value: role);
  }
}
