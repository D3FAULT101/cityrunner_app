import 'package:flutter/material.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/auth/passenger_otp_screen.dart';
import '../../screens/auth/passenger_phone_screen.dart';
import '../../screens/auth/onboarding_screen.dart';
import '../../screens/auth/role_selection_screen.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/booking/booking_confirmation_screen.dart';
import '../../screens/booking/payment_screen.dart';
import '../../screens/booking/seat_selection_screen.dart';
import '../../screens/driver/driver_dashboard_screen.dart';
import '../../screens/driver/incoming_ride_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/passenger/passenger_home_screen.dart';
import '../../screens/passenger/activity_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/fleet_map_screen.dart';
import '../../screens/tracking/tracking_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const roleSelection = '/role-selection';
  static const passengerHome = '/passenger';
  static const passengerPhone = '/passenger/phone';
  static const passengerOtp = '/passenger/otp';
  static const activity = '/passenger/activity';
  static const driverDashboard = '/driver';
  static const adminDashboard = '/admin';
  static const fleetMap = '/admin/fleet-map';
  static const seatSelection = '/booking/seats';
  static const payment = '/booking/payment';
  static const bookingConfirmation = '/booking/confirmation';
  static const tracking = '/tracking';
  static const notifications = '/notifications';
  static const incomingRide = '/driver/incoming-ride';
}

class AppRouter {
  const AppRouter._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Pops the current route if possible; otherwise falls back to a known
  /// route so a visible back arrow never silently does nothing (this is
  /// what caused the Role Selection back button to appear broken —
  /// onboarding had replaced itself out of the stack).
  static void goBack(BuildContext context, {String fallbackRoute = AppRoutes.roleSelection}) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, fallbackRoute);
    }
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) {
        switch (settings.name) {
          case AppRoutes.onboarding:
            return const OnboardingScreen();
          case AppRoutes.login:
            return const LoginScreen();
          case AppRoutes.roleSelection:
            return const RoleSelectionScreen();
          case AppRoutes.passengerHome:
            return const PassengerHomeScreen();
          case AppRoutes.passengerPhone:
            return const PassengerPhoneScreen();
          case AppRoutes.passengerOtp:
            return const PassengerOtpScreen();
          case AppRoutes.activity:
            return const ActivityScreen();
          case AppRoutes.seatSelection:
            return const SeatSelectionScreen();
          case AppRoutes.payment:
            return const PaymentScreen();
          case AppRoutes.bookingConfirmation:
            return const BookingConfirmationScreen();
          case AppRoutes.tracking:
            return const TrackingScreen();
          case AppRoutes.notifications:
            return const NotificationsScreen();
          case AppRoutes.driverDashboard:
            return const DriverDashboardScreen();
          case AppRoutes.incomingRide:
            return const IncomingRideScreen();
          case AppRoutes.adminDashboard:
            return const AdminDashboardScreen();
          case AppRoutes.fleetMap:
            return const FleetMapScreen();
          case AppRoutes.splash:
          default:
            return const SplashScreen();
        }
      },
    );
  }
}
