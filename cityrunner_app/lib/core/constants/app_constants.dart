import 'package:flutter/foundation.dart';

class AppConstants {
  const AppConstants._();

  static const appName = 'City Runner';
  static const tagline = 'Move Cities. Move People.';
  static const _configuredApiBaseUrl = String.fromEnvironment(
    'CITY_RUNNER_API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) return _configuredApiBaseUrl;
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static const driverTokenKey = 'city-runner-driver-token';
  static const adminTokenKey = 'city-runner-admin-token';
  static const passengerTokenKey = 'city-runner-passenger-token';
  static const fullRouteFare = 60;
  static const defaultRouteName = 'Gangtok -> Ranipool';
  static const publicPollSeconds = 8;
  static const driverPollSeconds = 6;
  static const adminPollSeconds = 8;
}
