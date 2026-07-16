import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'firebase_bootstrap.dart';

class RemoteConfigState {
  const RemoteConfigState({
    required this.maintenanceMode,
    required this.minimumAppVersion,
    required this.forceUpdate,
    required this.dynamicPricingMultiplier,
    required this.emergencyBanner,
    required this.enableDriverFeatures,
  });

  final bool maintenanceMode;
  final String minimumAppVersion;
  final bool forceUpdate;
  final double dynamicPricingMultiplier;
  final String emergencyBanner;
  final bool enableDriverFeatures;

  static const defaults = RemoteConfigState(
    maintenanceMode: false,
    minimumAppVersion: '1.0.0',
    forceUpdate: false,
    dynamicPricingMultiplier: 1,
    emergencyBanner: '',
    enableDriverFeatures: true,
  );
}

class RemoteConfigService {
  RemoteConfigService._();

  static final instance = RemoteConfigService._();

  Future<RemoteConfigState> fetch() async {
    if (!FirebaseBootstrap.isReady) return RemoteConfigState.defaults;
    final config = FirebaseRemoteConfig.instance;
    await config.setConfigSettings(
      RemoteConfigSettings(fetchTimeout: const Duration(seconds: 10), minimumFetchInterval: const Duration(hours: 1)),
    );
    await config.setDefaults({
      'maintenance_mode': false,
      'minimum_app_version': '1.0.0',
      'force_update': false,
      'pricing_multiplier': 1.0,
      'emergency_banner': '',
      'enable_driver_features': true,
    });
    await config.fetchAndActivate();
    return RemoteConfigState(
      maintenanceMode: config.getBool('maintenance_mode'),
      minimumAppVersion: config.getString('minimum_app_version'),
      forceUpdate: config.getBool('force_update'),
      dynamicPricingMultiplier: config.getDouble('pricing_multiplier'),
      emergencyBanner: config.getString('emergency_banner'),
      enableDriverFeatures: config.getBool('enable_driver_features'),
    );
  }
}
