import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/app_constants.dart';

class TokenStore {
  TokenStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> readDriverToken() => _storage.read(key: AppConstants.driverTokenKey);

  Future<String?> readAdminToken() => _storage.read(key: AppConstants.adminTokenKey);

  Future<String?> readPassengerToken() => _storage.read(key: AppConstants.passengerTokenKey);

  Future<void> saveDriverToken(String token) => _storage.write(key: AppConstants.driverTokenKey, value: token);

  Future<void> saveAdminToken(String token) => _storage.write(key: AppConstants.adminTokenKey, value: token);

  Future<void> savePassengerToken(String token) => _storage.write(key: AppConstants.passengerTokenKey, value: token);

  Future<void> clearDriverToken() => _storage.delete(key: AppConstants.driverTokenKey);

  Future<void> clearAdminToken() => _storage.delete(key: AppConstants.adminTokenKey);

  Future<void> clearPassengerToken() => _storage.delete(key: AppConstants.passengerTokenKey);
}
