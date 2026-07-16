import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/utils/geo_utils.dart';
import '../models/city_runner_models.dart';
import '../repositories/city_runner_repository.dart';
import '../services/api_service.dart';
import '../services/token_store.dart';
import '../services/websocket_service.dart';

class AppProvider extends ChangeNotifier {
  AppProvider(this._repository, {TokenStore? tokenStore}) : _tokenStore = tokenStore ?? TokenStore();

  final CityRunnerRepository _repository;
  final TokenStore _tokenStore;

  List<BusState> publicBuses = const [];
  DriverDashboard? driverDashboard;
  AdminOverview? adminOverview;
  SessionUser? driverUser;
  SessionUser? adminUser;
  PassengerAccount? passengerUser;
  UserRole selectedRole = UserRole.passenger;
  int? selectedBusId;
  Coordinate? passengerLocation;
  Coordinate? driverPhoneLocation;
  String? driverToken;
  String? adminToken;
  String? passengerToken;
  String? errorMessage;
  String? successMessage;
  UserRole? authRedirectRole;
  bool isLoading = true;
  String? busyAction;

  // Real-time (WebSocket) state
  bool publicSocketConnected = false;
  bool driverSocketConnected = false;
  bool adminSocketConnected = false;

  /// Bookings waiting on this driver's accept/reject (Incoming Ride screen).
  List<Booking> pendingDriverBookings = const [];

  /// The most recent booking request that hasn't been shown to the driver
  /// yet. Screens watch this and call [consumeIncomingBooking] once shown,
  /// mirroring the [consumeAuthRedirect] pattern below.
  Booking? incomingBooking;

  /// The passenger's active booking (set after checkout), used by the
  /// Booking Confirmation and Tracking screens.
  Booking? currentBooking;

  List<AppNotification> notifications = const [];
  List<Booking> passengerTripHistory = const [];

  // Draft selection carried from Seat Selection -> Payment (not yet booked).
  List<int> draftSeatIds = const [];
  int? draftPickupStopId;
  int? draftDestinationStopId;

  void setDraftBooking({
    required List<int> seatIds,
    required int pickupStopId,
    required int destinationStopId,
  }) {
    draftSeatIds = seatIds;
    draftPickupStopId = pickupStopId;
    draftDestinationStopId = destinationStopId;
    notifyListeners();
  }

  Timer? _publicTimer;
  Timer? _driverTimer;
  Timer? _adminTimer;
  StreamSubscription<Position>? _driverLocationSubscription;
  DateTime? _lastDriverPush;

  RealtimeChannel? _publicChannel;
  RealtimeChannel? _driverChannel;
  RealtimeChannel? _adminChannel;
  RealtimeChannel? _bookingChannel;

  BusState? get selectedBus {
    if (selectedRole == UserRole.driver && driverDashboard?.bus != null) {
      return driverDashboard!.bus;
    }
    final buses = visibleBuses;
    for (final bus in buses) {
      if (bus.id == selectedBusId) return bus;
    }
    return buses.isEmpty ? null : buses.first;
  }

  List<BusState> get visibleBuses {
    if (publicBuses.isNotEmpty) return publicBuses;
    if (adminOverview?.buses.isNotEmpty ?? false) return adminOverview!.buses;
    if (driverDashboard?.bus != null) return [driverDashboard!.bus!];
    return const [];
  }

  double? get distanceToSelectedBus {
    final busPosition = selectedBus?.position;
    if (busPosition == null || passengerLocation == null) return null;
    return haversineDistanceKm(passengerLocation!, busPosition);
  }

  Future<void> bootstrap() async {
    isLoading = true;
    notifyListeners();
    driverToken = await _tokenStore.readDriverToken();
    adminToken = await _tokenStore.readAdminToken();
    passengerToken = await _tokenStore.readPassengerToken();
    await Future.wait([
      refreshPublic(),
      _restoreDriverSession(),
      _restoreAdminSession(),
      _restorePassengerSession(),
    ]);
    _connectPublicChannel();
    if (driverToken != null) _connectDriverChannel();
    if (adminToken != null) _connectAdminChannel();
    _startPolling();
    isLoading = false;
    notifyListeners();
  }

Future<bool> login(
  String username,
  String password,
  UserRole role,
) async {
  final success = await _guard('login', () async {
    final result = await _repository.login(
      username.trim(),
      password,
    );

    if (!result.success ||
        result.token == null ||
        result.user == null) {
      throw StateError(result.message);
    }

    if (result.user!.role != role) {
      if (result.token != null) {
        try {
          await _repository.logout(result.token!);
        } catch (_) {}
      }
      throw StateError(
        'These credentials belong to a ${roleToJson(result.user!.role)} account.',
      );
    }

    if (role == UserRole.driver) {
      driverToken = result.token;
      driverUser = result.user;
      selectedRole = UserRole.driver;

      await _tokenStore.saveDriverToken(result.token!);

      await refreshDriver();
      await startDriverLocationStream();
      _connectDriverChannel();
    } else if (role == UserRole.admin) {
      adminToken = result.token;
      adminUser = result.user;
      selectedRole = UserRole.admin;

      await _tokenStore.saveAdminToken(result.token!);

      await refreshAdmin();
      _connectAdminChannel();
    }

    successMessage = result.message;
  });

  return success;
}

  Future<void> refreshPublic() async {
    try {
      publicBuses = await _repository.fetchPublicBuses();
      selectedBusId ??= publicBuses.isEmpty ? null : publicBuses.first.id;
      errorMessage = null;
    } catch (error) {
      errorMessage = _readableError(error);
    }
    notifyListeners();
  }

  Future<void> refreshDriver() async {
    if (driverToken == null) return;
    try {
      driverDashboard = await _repository.fetchDriverDashboard(driverToken!);
      driverUser = driverDashboard!.user;
      selectedBusId = driverDashboard!.bus?.id ?? selectedBusId;
    } catch (error) {
      if (error is ApiUnauthorizedException) {
        await _expireSession(UserRole.driver, error.message);
        return;
      }
      errorMessage = _readableError(error);
    }
    notifyListeners();
  }

  Future<void> refreshAdmin() async {
    if (adminToken == null) return;
    try {
      adminOverview = await _repository.fetchAdminOverview(adminToken!);
      selectedBusId ??= adminOverview!.buses.isEmpty ? null : adminOverview!.buses.first.id;
    } catch (error) {
      if (error is ApiUnauthorizedException) {
        await _expireSession(UserRole.admin, error.message);
        return;
      }
      errorMessage = _readableError(error);
    }
    notifyListeners();
  }

  Future<bool> requestPassengerOtp(String phoneNumber) async {
    return _guard('request-passenger-otp', () async {
      final devCode = await _repository.requestOtp(phoneNumber.trim());
      successMessage = devCode == null ? 'Verification code sent.' : 'Dev code: $devCode';
    });
  }

  Future<bool> verifyPassengerOtp(String phoneNumber, String code) async {
    return _guard('verify-passenger-otp', () async {
      final result = await _repository.verifyOtp(phoneNumber.trim(), code.trim());
      passengerToken = result.token;
      passengerUser = result.passenger;
      selectedRole = UserRole.passenger;
      await _tokenStore.savePassengerToken(result.token);
      await refreshTripHistory();
      successMessage = 'Phone verified.';
    });
  }

  Future<void> refreshTripHistory() async {
    if (passengerToken == null) return;
    try {
      passengerTripHistory = await _repository.fetchPassengerBookings(passengerToken!);
      notifyListeners();
    } catch (error) {
      if (error is ApiUnauthorizedException) {
        await _expireSession(UserRole.passenger, error.message);
      }
    }
  }

  Future<void> locatePassenger() async {
    await _guard('locate-passenger', () async {
      final position = await _currentPosition();
      passengerLocation = Coordinate(lat: position.latitude, lng: position.longitude);
      successMessage = 'Current location added.';
    });
  }

  Future<void> syncDriverLocationNow() async {
    await _guard('driver-sync', () async {
      if (driverToken == null) throw StateError('Driver login required.');
      final position = await _currentPosition();
      await _pushDriverLocation(position);
      successMessage = 'Live bus location synced from this phone.';
      await Future.wait([refreshPublic(), refreshDriver()]);
    });
  }

  Future<void> startDriverLocationStream() async {
    if (driverToken == null) return;
    await _driverLocationSubscription?.cancel();
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      errorMessage = 'Location services are disabled.';
      notifyListeners();
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      errorMessage = 'Driver GPS permission was denied.';
      notifyListeners();
      return;
    }

    _driverLocationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) async {
      driverPhoneLocation = Coordinate(lat: position.latitude, lng: position.longitude);
      final last = _lastDriverPush;
      if (last != null && DateTime.now().difference(last).inSeconds < 7) {
        notifyListeners();
        return;
      }
      try {
        await _pushDriverLocation(position);
      } catch (error) {
        errorMessage = _readableError(error);
      }
      notifyListeners();
    });
  }

  Future<bool> toggleSeat(int seatId) async {
    return _mutate('seat-$seatId', () => _repository.toggleDriverSeat(driverToken!, seatId));
  }

  Future<bool> resetSeats() async {
    return _mutate('reset-seats', () => _repository.resetDriverSeats(driverToken!));
  }

  Future<bool> toggleBusStatus() async {
    return _mutate('toggle-bus', () => _repository.toggleDriverBus(driverToken!));
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    final token = selectedRole == UserRole.driver ? driverToken : adminToken;
    if (token == null) return false;
    return _guard('change-password', () async {
      final result = await _repository.changePassword(token, currentPassword, newPassword);
      if (selectedRole == UserRole.driver && driverUser != null) {
        driverUser = driverUser!.copyWith(mustChangePassword: false);
        if (driverDashboard != null) {
          driverDashboard = DriverDashboard(
            user: driverDashboard!.user.copyWith(mustChangePassword: false),
            bus: driverDashboard!.bus,
          );
        }
      }
      if (selectedRole == UserRole.admin && adminUser != null) {
        adminUser = adminUser!.copyWith(mustChangePassword: false);
      }
      successMessage = result.message;
    });
  }

  Future<bool> createBus(String name, String registrationNumber, String routeName) async {
    return _mutate('create-bus', () => _repository.createBus(adminToken!, name, registrationNumber, routeName));
  }

  Future<bool> createDriver(String username, String displayName, String password, int? assignedBusId) async {
    return _mutate(
      'create-driver',
      () => _repository.createDriver(adminToken!, username, displayName, password, assignedBusId),
    );
  }

  Future<bool> resetDriverPassword(int driverId, String newPassword) async {
    return _mutate('reset-driver-password', () => _repository.resetDriverPassword(adminToken!, driverId, newPassword));
  }

  Future<bool> removeDriver(int driverId, String adminPassword) async {
    return _mutate('remove-driver', () => _repository.removeDriver(adminToken!, driverId, adminPassword));
  }

  // ── Bookings (passenger) ────────────────────────────────────────────────

  Future<bool> createBooking({
    required int busId,
    required List<int> seatIds,
    required int pickupStopId,
    required int destinationStopId,
    required String paymentMethod,
    String passengerName = 'Passenger',
  }) async {
    return _guard('create-booking', () async {
      final booking = await _repository.createBooking(
        busId: busId,
        seatIds: seatIds,
        pickupStopId: pickupStopId,
        destinationStopId: destinationStopId,
        paymentMethod: paymentMethod,
        passengerName: passengerName,
        passengerToken: passengerToken,
      );
      currentBooking = booking;
      successMessage = 'Booking request sent to the driver.';
      _connectBookingChannel(booking.publicCode);
      await refreshPublic();
      await refreshTripHistory();
    });
  }

  Future<void> refreshCurrentBooking() async {
    final code = currentBooking?.publicCode;
    if (code == null) return;
    try {
      currentBooking = await _repository.fetchBooking(code);
      notifyListeners();
    } catch (_) {
      // Keep the last known state; the booking channel will retry the push.
    }
  }

  void clearCurrentBooking() {
    currentBooking = null;
    _bookingChannel?.dispose();
    _bookingChannel = null;
    notifyListeners();
  }

  // ── Bookings (driver) ────────────────────────────────────────────────────

  Future<void> refreshPendingBookings() async {
    if (driverToken == null) return;
    try {
      pendingDriverBookings = await _repository.fetchPendingBookings(driverToken!);
      notifyListeners();
    } catch (error) {
      if (error is ApiUnauthorizedException) {
        await _expireSession(UserRole.driver, error.message);
      }
    }
  }

  Future<bool> respondToBooking(int bookingId, bool accept) async {
    return _guard('respond-booking', () async {
      await _repository.respondToBooking(driverToken!, bookingId, accept);
      pendingDriverBookings = pendingDriverBookings.where((b) => b.id != bookingId).toList();
      if (incomingBooking?.id == bookingId) incomingBooking = null;
      successMessage = accept ? 'Ride accepted.' : 'Ride declined.';
      await Future.wait([refreshDriver(), refreshPublic()]);
    });
  }

  Booking? consumeIncomingBooking() {
    final booking = incomingBooking;
    incomingBooking = null;
    return booking;
  }

  // ── Notifications ────────────────────────────────────────────────────────

  Future<void> refreshNotifications() async {
    final token = selectedRole == UserRole.admin ? adminToken : driverToken;
    if (token == null) return;
    try {
      notifications = await _repository.fetchNotifications(token);
      notifyListeners();
    } catch (_) {
      // Non-critical; leave the last known list in place.
    }
  }

  Future<void> markNotificationRead(int notificationId) async {
    final token = selectedRole == UserRole.admin ? adminToken : driverToken;
    if (token == null) return;
    try {
      await _repository.markNotificationRead(token, notificationId);
      notifications = notifications
          .map((n) => n.id == notificationId
              ? AppNotification(
                  id: n.id,
                  kind: n.kind,
                  title: n.title,
                  body: n.body,
                  bookingId: n.bookingId,
                  createdAt: n.createdAt,
                  readAt: DateTime.now(),
                )
              : n)
          .toList();
      notifyListeners();
    } catch (_) {
      // Ignore — not critical to app function.
    }
  }

  Future<void> logout(UserRole role) async {
    if (role == UserRole.driver) {
      final token = driverToken;
      if (token != null) {
        try {
          await _repository.logout(token);
        } catch (_) {}
      }
      await _tokenStore.clearDriverToken();
      await _driverLocationSubscription?.cancel();
      _driverChannel?.dispose();
      _driverChannel = null;
      driverSocketConnected = false;
      driverToken = null;
      driverUser = null;
      driverDashboard = null;
      pendingDriverBookings = const [];
      incomingBooking = null;
      if (selectedRole == UserRole.driver) selectedRole = UserRole.passenger;
    } else if (role == UserRole.admin) {
      final token = adminToken;
      if (token != null) {
        try {
          await _repository.logout(token);
        } catch (_) {}
      }
      await _tokenStore.clearAdminToken();
      _adminChannel?.dispose();
      _adminChannel = null;
      adminSocketConnected = false;
      adminToken = null;
      adminUser = null;
      adminOverview = null;
      if (selectedRole == UserRole.admin) selectedRole = UserRole.passenger;
    } else if (role == UserRole.passenger) {
      final token = passengerToken;
      if (token != null) {
        try {
          await _repository.logout(token);
        } catch (_) {}
      }
      await _tokenStore.clearPassengerToken();
      passengerToken = null;
      passengerUser = null;
      passengerTripHistory = const [];
    }
    successMessage = '${role == UserRole.driver ? 'Driver' : role == UserRole.admin ? 'Admin' : 'Passenger'} session cleared.';
    notifyListeners();
  }

  void selectBus(int busId) {
    selectedBusId = busId;
    notifyListeners();
  }

  void selectRole(UserRole role) {
    selectedRole = role;
    notifyListeners();
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
    notifyListeners();
  }

  UserRole? consumeAuthRedirect() {
    final role = authRedirectRole;
    authRedirectRole = null;
    return role;
  }

  Future<void> _restoreDriverSession() async {
    if (driverToken == null) return;
    try {
      driverUser = await _repository.fetchCurrentUser(driverToken!);
      await refreshDriver();
      await startDriverLocationStream();
    } catch (_) {
      await _tokenStore.clearDriverToken();
      driverToken = null;
    }
  }

  Future<void> _restoreAdminSession() async {
    if (adminToken == null) return;
    try {
      adminUser = await _repository.fetchCurrentUser(adminToken!);
      await refreshAdmin();
    } catch (_) {
      await _tokenStore.clearAdminToken();
      adminToken = null;
    }
  }

  Future<void> _restorePassengerSession() async {
    if (passengerToken == null) return;
    try {
      passengerUser = await _repository.fetchPassengerProfile(passengerToken!);
      await refreshTripHistory();
    } catch (_) {
      await _tokenStore.clearPassengerToken();
      passengerToken = null;
      passengerUser = null;
    }
  }

  void _startPolling() {
    _publicTimer?.cancel();
    _driverTimer?.cancel();
    _adminTimer?.cancel();
    // WebSockets are now the primary update path (see _connect*Channel below).
    // These polling timers are just a safety net in case a socket is stuck
    // reconnecting, so they run much less often than before.
    const fallbackInterval = Duration(seconds: 45);
    _publicTimer = Timer.periodic(fallbackInterval, (_) => refreshPublic());
    _driverTimer = Timer.periodic(fallbackInterval, (_) => refreshDriver());
    _adminTimer = Timer.periodic(fallbackInterval, (_) => refreshAdmin());
  }

  // ── Real-time (WebSocket) plumbing ──────────────────────────────────────

  void _connectPublicChannel() {
    _publicChannel?.dispose();
    _publicChannel = RealtimeChannel(
      path: '/ws/public',
      onConnected: () {
        if (!publicSocketConnected) {
          publicSocketConnected = true;
          notifyListeners();
        }
      },
      onDisconnected: () {
        if (publicSocketConnected) {
          publicSocketConnected = false;
          notifyListeners();
        }
      },
      onMessage: _handlePublicMessage,
    )..connect();
  }

  void _handlePublicMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'bus_updated':
        _upsertPublicBus(BusState.fromJson(message['bus'] as Map<String, dynamic>));
        notifyListeners();
      case 'buses_updated':
        publicBuses = (message['buses'] as List<dynamic>)
            .map((item) => BusState.fromJson(item as Map<String, dynamic>))
            .toList();
        notifyListeners();
    }
  }

  void _upsertPublicBus(BusState bus) {
    final index = publicBuses.indexWhere((b) => b.id == bus.id);
    if (index == -1) {
      publicBuses = [...publicBuses, bus];
    } else {
      final updated = [...publicBuses];
      updated[index] = bus;
      publicBuses = updated;
    }
  }

  void _connectDriverChannel() {
    if (driverToken == null) return;
    _driverChannel?.dispose();
    _driverChannel = RealtimeChannel(
      path: '/ws/driver?token=$driverToken',
      onConnected: () {
        driverSocketConnected = true;
        notifyListeners();
        refreshPendingBookings();
      },
      onDisconnected: () {
        driverSocketConnected = false;
        notifyListeners();
      },
      onMessage: _handleDriverMessage,
    )..connect();
  }

  void _handleDriverMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'bus_updated':
        final bus = BusState.fromJson(message['bus'] as Map<String, dynamic>);
        if (driverDashboard != null) {
          driverDashboard = DriverDashboard(user: driverDashboard!.user, bus: bus);
        }
        notifyListeners();
      case 'incoming_booking':
        final booking = Booking.fromJson(message['booking'] as Map<String, dynamic>);
        pendingDriverBookings = [
          ...pendingDriverBookings.where((b) => b.id != booking.id),
          booking,
        ];
        incomingBooking = booking;
        notifyListeners();
      case 'session_revoked':
        unawaited(_expireSession(
          UserRole.driver,
          message['reason'] as String? ?? 'Your session was ended by an admin.',
        ));
    }
  }

  void _connectAdminChannel() {
    if (adminToken == null) return;
    _adminChannel?.dispose();
    _adminChannel = RealtimeChannel(
      path: '/ws/admin?token=$adminToken',
      onConnected: () {
        adminSocketConnected = true;
        notifyListeners();
      },
      onDisconnected: () {
        adminSocketConnected = false;
        notifyListeners();
      },
      onMessage: _handleAdminMessage,
    )..connect();
  }

  void _handleAdminMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'admin_overview_updated':
        final buses = (message['buses'] as List<dynamic>)
            .map((item) => BusState.fromJson(item as Map<String, dynamic>))
            .toList();
        final drivers = (message['drivers'] as List<dynamic>)
            .map((item) => DriverSummary.fromJson(item as Map<String, dynamic>))
            .toList();
        adminOverview = AdminOverview(buses: buses, drivers: drivers);
        notifyListeners();
      case 'bus_updated':
        if (adminOverview != null) {
          final bus = BusState.fromJson(message['bus'] as Map<String, dynamic>);
          final buses = [...adminOverview!.buses];
          final index = buses.indexWhere((b) => b.id == bus.id);
          if (index != -1) {
            buses[index] = bus;
          } else {
            buses.add(bus);
          }
          adminOverview = AdminOverview(buses: buses, drivers: adminOverview!.drivers);
        }
        notifyListeners();
    }
  }

  void _connectBookingChannel(String publicCode) {
    _bookingChannel?.dispose();
    _bookingChannel = RealtimeChannel(
      path: '/ws/booking/$publicCode',
      onMessage: (message) {
        if (message['type'] == 'booking_updated') {
          currentBooking = Booking.fromJson(message['booking'] as Map<String, dynamic>);
          notifyListeners();
        }
      },
    )..connect();
  }

  @override
  void dispose() {
    _publicTimer?.cancel();
    _driverTimer?.cancel();
    _adminTimer?.cancel();
    _driverLocationSubscription?.cancel();
    _publicChannel?.dispose();
    _driverChannel?.dispose();
    _adminChannel?.dispose();
    _bookingChannel?.dispose();
    super.dispose();
  }

  Future<Position> _currentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw StateError('Location services are disabled.');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw StateError('Location permission was denied.');
    }
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }

  Future<void> _pushDriverLocation(Position position) async {
    await _repository.updateDriverLocation(driverToken!, position.latitude, position.longitude, position.accuracy);
    _lastDriverPush = DateTime.now();
    driverPhoneLocation = Coordinate(lat: position.latitude, lng: position.longitude);
  }

  Future<bool> _mutate(String action, Future<MutationResult> Function() callback) async {
    return _guard(action, () async {
      final result = await callback();
      successMessage = result.message;
      await Future.wait([refreshPublic(), refreshDriver(), refreshAdmin()]);
    });
  }

  Future<bool> _guard(String action, Future<void> Function() callback) async {
    busyAction = action;
    errorMessage = null;
    notifyListeners();
    try {
      await callback();
      return true;
    } catch (error) {
      if (error is ApiUnauthorizedException) {
        final role = selectedRole == UserRole.admin ? UserRole.admin : UserRole.driver;
        await _expireSession(role, error.message);
        return false;
      }
      errorMessage = _readableError(error);
      return false;
    } finally {
      busyAction = null;
      notifyListeners();
    }
  }

  Future<void> _expireSession(UserRole role, String message) async {
    if (role == UserRole.driver) {
      await _tokenStore.clearDriverToken();
      await _driverLocationSubscription?.cancel();
      _driverChannel?.dispose();
      _driverChannel = null;
      driverSocketConnected = false;
      driverToken = null;
      driverUser = null;
      driverDashboard = null;
      pendingDriverBookings = const [];
      incomingBooking = null;
    } else if (role == UserRole.admin) {
      await _tokenStore.clearAdminToken();
      _adminChannel?.dispose();
      _adminChannel = null;
      adminSocketConnected = false;
      adminToken = null;
      adminUser = null;
      adminOverview = null;
    } else if (role == UserRole.passenger) {
      await _tokenStore.clearPassengerToken();
      passengerToken = null;
      passengerUser = null;
      passengerTripHistory = const [];
    }
    selectedRole = role;
    authRedirectRole = role;
    errorMessage = message.isEmpty ? 'Session expired. Please log in again.' : message;
    notifyListeners();
  }

  String _readableError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
    return message.isEmpty ? 'Request failed.' : message;
  }

}
