import '../models/city_runner_models.dart';
import '../services/api_service.dart';

class CityRunnerRepository {
  const CityRunnerRepository(this._api);

  final ApiService _api;

  Future<List<BusState>> fetchPublicBuses() async {
    final data = await _api.get('/api/public/buses');
    return (data['buses'] as List<dynamic>)
        .map((item) => BusState.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<LoginResult> login(String username, String password) async {
    return LoginResult.fromJson(
      await _api.post('/api/auth/login', data: {'username': username, 'password': password}),
    );
  }

  Future<SessionUser> fetchCurrentUser(String token) async {
    return SessionUser.fromJson(await _api.get('/api/auth/me', token: token));
  }

  Future<String?> requestOtp(String phoneNumber) async {
    final data = await _api.post('/api/auth/otp/request', data: {'phone_number': phoneNumber});
    return data['dev_code'] as String?;
  }

  Future<PassengerLoginResult> verifyOtp(String phoneNumber, String code) async {
    return PassengerLoginResult.fromJson(await _api.post(
      '/api/auth/otp/verify',
      data: {'phone_number': phoneNumber, 'code': code},
    ));
  }

  Future<PassengerAccount> fetchPassengerProfile(String token) async {
    return PassengerAccount.fromJson(await _api.get('/api/passenger/me', token: token));
  }

  Future<MutationResult> logout(String token) async {
    return MutationResult.fromJson(await _api.post('/api/auth/logout', token: token));
  }

  Future<MutationResult> changePassword(String token, String currentPassword, String newPassword) async {
    return MutationResult.fromJson(await _api.post(
      '/api/auth/change-password',
      token: token,
      data: {'current_password': currentPassword, 'new_password': newPassword},
    ));
  }

  Future<DriverDashboard> fetchDriverDashboard(String token) async {
    return DriverDashboard.fromJson(await _api.get('/api/driver/dashboard', token: token));
  }

  Future<MutationResult> updateDriverLocation(
    String token,
    double lat,
    double lng,
    double? accuracyMeters,
  ) async {
    return MutationResult.fromJson(await _api.post(
      '/api/driver/location',
      token: token,
      data: {'lat': lat, 'lng': lng, 'accuracy_meters': accuracyMeters},
    ));
  }

  Future<MutationResult> toggleDriverSeat(String token, int seatId) async {
    return MutationResult.fromJson(await _api.post('/api/driver/seats/$seatId/toggle', token: token));
  }

  Future<MutationResult> resetDriverSeats(String token) async {
    return MutationResult.fromJson(await _api.post('/api/driver/seats/reset', token: token));
  }

  Future<MutationResult> toggleDriverBus(String token) async {
    return MutationResult.fromJson(await _api.post('/api/driver/bus/toggle-active', token: token));
  }

  Future<AdminOverview> fetchAdminOverview(String token) async {
    return AdminOverview.fromJson(await _api.get('/api/admin/overview', token: token));
  }

  Future<MutationResult> createBus(String token, String name, String registrationNumber, String routeName) async {
    return MutationResult.fromJson(await _api.post(
      '/api/admin/buses',
      token: token,
      data: {'name': name, 'registration_number': registrationNumber, 'route_name': routeName},
    ));
  }

  Future<MutationResult> createDriver(
    String token,
    String username,
    String displayName,
    String password,
    int? assignedBusId,
  ) async {
    return MutationResult.fromJson(await _api.post(
      '/api/admin/drivers',
      token: token,
      data: {
        'username': username,
        'display_name': displayName,
        'password': password,
        'assigned_bus_id': assignedBusId,
      },
    ));
  }

  Future<MutationResult> resetDriverPassword(String token, int driverId, String newPassword) async {
    return MutationResult.fromJson(await _api.post(
      '/api/admin/drivers/$driverId/reset-password',
      token: token,
      data: {'new_password': newPassword},
    ));
  }

  Future<MutationResult> removeDriver(String token, int driverId, String adminPassword) async {
    return MutationResult.fromJson(await _api.delete(
      '/api/admin/drivers/$driverId',
      token: token,
      data: {'admin_password': adminPassword},
    ));
  }

  Future<Booking> createBooking({
    required int busId,
    required List<int> seatIds,
    required int pickupStopId,
    required int destinationStopId,
    required String paymentMethod,
    String passengerName = 'Passenger',
    String? passengerToken,
  }) async {
    return Booking.fromJson(await _api.post(
      '/api/public/bookings',
      token: passengerToken,
      data: {
        'bus_id': busId,
        'seat_ids': seatIds,
        'pickup_stop_id': pickupStopId,
        'destination_stop_id': destinationStopId,
        'payment_method': paymentMethod,
        'passenger_name': passengerName,
      },
    ));
  }

  Future<Booking> fetchBooking(String publicCode) async {
    return Booking.fromJson(await _api.get('/api/public/bookings/$publicCode'));
  }

  Future<List<Booking>> fetchPassengerBookings(String token) async {
    final data = await _api.getList('/api/passenger/bookings', token: token);
    return data.map((item) => Booking.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Booking>> fetchPendingBookings(String driverToken) async {
    final data = await _api.getList('/api/driver/bookings/pending', token: driverToken);
    return data.map((item) => Booking.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Booking> respondToBooking(String driverToken, int bookingId, bool accept) async {
    return Booking.fromJson(await _api.post(
      '/api/driver/bookings/$bookingId/respond',
      token: driverToken,
      data: {'accept': accept},
    ));
  }

  Future<List<AppNotification>> fetchNotifications(String token) async {
    final data = await _api.get('/api/notifications', token: token);
    return (data['notifications'] as List<dynamic>)
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MutationResult> markNotificationRead(String token, int notificationId) async {
    return MutationResult.fromJson(await _api.post('/api/notifications/$notificationId/read', token: token));
  }
}
