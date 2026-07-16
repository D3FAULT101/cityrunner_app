import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/geo_utils.dart';
import '../../models/city_runner_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/seat_grid.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dashboard = app.driverDashboard;
    final bus = dashboard?.bus;

    // A fresh ride request arrived over the driver WebSocket channel — jump
    // straight to the Incoming Ride screen so the driver can respond before
    // it goes stale, the same way the workflow diagram shows.
    if (app.incomingBooking != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AppProvider>().consumeIncomingBooking();
        Navigator.pushNamed(context, AppRoutes.incomingRide);
      });
    }

    return PhoneFrame(
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => Future.wait([
              context.read<AppProvider>().refreshDriver(),
              context.read<AppProvider>().refreshPendingBookings(),
            ]),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    const Icon(Icons.drive_eta, color: AppTheme.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        dashboard?.user.displayName ?? 'Driver Dashboard',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    ConnectionDot(connected: app.driverSocketConnected),
                    const SizedBox(width: 6),
                    if (app.driverToken != null)
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                        icon: const Icon(Icons.notifications_outlined),
                      ),
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: () async {
                        await context.read<AppProvider>().logout(UserRole.driver);
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.roleSelection, (_) => false);
                      },
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (app.driverToken == null)
                  _LoginRequired(
                    onLogin: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (_) => false,
                      arguments: UserRole.driver,
                    ),
                  )
                else if (bus == null)
                  const CityPanel(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No bus is assigned to this driver yet. Ask an admin to assign a bus.'),
                    ),
                  )
                else ...[
                  if (dashboard?.user.mustChangePassword ?? false) ...[
                    CityPanel(
                      child: Row(
                        children: [
                          const Icon(Icons.lock_reset, color: AppTheme.accent),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Change your temporary password.')),
                          TextButton(
                            onPressed: () => _showChangePasswordDialog(context),
                            child: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (app.pendingDriverBookings.isNotEmpty) ...[
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.incomingRide),
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      child: CityPanel(
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_rounded, color: AppTheme.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${app.pendingDriverBookings.length} ride request${app.pendingDriverBookings.length > 1 ? 's' : ''} waiting',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _BusSummary(bus: bus),
                  const SizedBox(height: 16),
                  CityPanel(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (bus.isActive ? AppTheme.accent : AppTheme.elevated).withValues(alpha: bus.isActive ? .15 : 1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            bus.isActive ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                            color: bus.isActive ? AppTheme.accent : AppTheme.muted,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('You are', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                              Text(
                                bus.isActive ? 'ONLINE' : 'OFFLINE',
                                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: bus.isActive,
                          onChanged: app.busyAction == 'toggle-bus'
                              ? null
                              : (_) => context.read<AppProvider>().toggleBusStatus(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GradientButton(
                    label: 'Sync GPS / Go To Current Location',
                    icon: Icons.my_location,
                    busy: app.busyAction == 'driver-sync',
                    onPressed: () => context.read<AppProvider>().syncDriverLocationNow(),
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle(title: 'Seat Control', subtitle: 'Tap a seat to mark it booked or free.'),
                  const SizedBox(height: 12),
                  CityPanel(
                    child: SeatGrid(
                      seats: bus.seats,
                      readOnly: false,
                      onToggleSeat: (seatId) {
                        context.read<AppProvider>().toggleSeat(seatId);
                      },
                      busyAction: app.busyAction,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: app.busyAction == 'reset-seats' ? null : () => context.read<AppProvider>().resetSeats(),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset All Seats'),
                  ),
                ],
              ],
            ),
          ),
          CitySnackHost(
            message: app.errorMessage ?? app.successMessage,
            isError: app.errorMessage != null,
            onDismiss: () => context.read<AppProvider>().clearMessages(),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPassword,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final ok = await context.read<AppProvider>().changePassword(currentPassword.text, newPassword.text);
                if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    } finally {
      currentPassword.dispose();
      newPassword.dispose();
    }
  }
}

class _BusSummary extends StatelessWidget {
  const _BusSummary({required this.bus});

  final BusState bus;

  @override
  Widget build(BuildContext context) {
    return CityPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bus.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    Text(bus.registrationNumber, style: const TextStyle(color: AppTheme.muted)),
                  ],
                ),
              ),
              Chip(
                label: Text(bus.isActive ? 'Active' : 'Offline'),
                backgroundColor: bus.isActive ? const Color(0xFF153B24) : const Color(0xFF3B1515),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(bus.routeName, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _InlineStat(label: 'Seats Left', value: '${bus.availableSeats}', icon: Icons.event_seat),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InlineStat(label: 'GPS', value: bus.hasLiveLocation ? 'Live' : 'Waiting', icon: Icons.gps_fixed),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(formatLastSeen(bus.locationUpdatedAt), style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return CityPanel(
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: AppTheme.accent, size: 36),
          const SizedBox(height: 12),
          const Text('Driver login required.'),
          const SizedBox(height: 14),
          GradientButton(label: 'Login', icon: Icons.login, onPressed: onLogin),
        ],
      ),
    );
  }
}
