import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_runner_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/tracking_map.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  void _callDriver(BuildContext context, String? driverName) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(driverName == null ? 'Call Driver' : 'Call $driverName'),
        content: const Text(
          "This driver hasn't added a contact number yet. You'll still get live status updates on this screen.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  void _shareLocation(BuildContext context, Booking? booking, BusState bus) {
    final link = booking != null
        ? 'https://cityrunner.app/track/${booking.publicCode}'
        : 'https://cityrunner.app/bus/${bus.id}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking link copied — share it with anyone.')),
    );
  }

  void _contactSupport(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text('Need help with this trip? Reach us at support@cityrunner.app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final bus = app.selectedBus;
    final booking = app.currentBooking;

    if (bus == null) {
      return const PhoneFrame(
        child: Center(
          child: Text('No active booking found'),
        ),
      );
    }

    return PhoneFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => AppRouter.goBack(context, fallbackRoute: AppRoutes.passengerHome),
                  icon: const Icon(Icons.arrow_back_ios_new),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Live Tracking',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.gps_fixed,
                  color: AppTheme.accent,
                ),
              ],
            ),

            if (booking != null) ...[
              const SizedBox(height: 14),
              _BookingStatusBanner(booking: booking),
            ],

            const SizedBox(height: 20),

            CityPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_bus,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bus.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${bus.registrationNumber} · ${bus.routeName}',
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: bus.hasLiveLocation ? AppTheme.accent : AppTheme.elevated,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          bus.hasLiveLocation ? 'LIVE' : 'OFFLINE',
                          style: TextStyle(
                            color: bus.hasLiveLocation ? Colors.white : AppTheme.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (bus.etaMinutes != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: .35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_filled, color: AppTheme.accent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your bus is arriving in ${bus.etaMinutes} minutes',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            TrackingMap(
              buses: app.visibleBuses,
              selectedBus: bus,
              viewerLocation: app.passengerLocation,
              onLocate: () {
                context.read<AppProvider>().locatePassenger();
              },
              locateLabel: 'Locate',
              height: 220,
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'ETA',
                    value: '${bus.etaMinutes ?? "--"} min',
                    icon: Icons.timer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    label: 'Seats Left',
                    value: '${bus.availableSeats}',
                    icon: Icons.event_seat,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            const SectionTitle(
              title: 'Driver Details',
              subtitle: 'Assigned driver information',
            ),

            const SizedBox(height: 12),

            CityPanel(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.accent,
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bus.assignedDriver?.displayName ??
                              'Driver Not Assigned',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          bus.registrationNumber,
                          style: const TextStyle(
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _callDriver(context, bus.assignedDriver?.displayName),
                    icon: const Icon(Icons.call),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const SectionTitle(
              title: 'Upcoming Stops',
              subtitle: 'Route progress',
            ),

            const SizedBox(height: 12),

            CityPanel(
              child: Column(
                children: List.generate(
                  bus.stops.length,
                  (index) {
                    final stop = bus.stops[index];

                    final isCurrent =
                        index == (bus.currentStopIndex ?? 0);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: isCurrent
                            ? AppTheme.accent
                            : AppTheme.elevated,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                          ),
                        ),
                      ),
                      title: Text(stop.name),
                      subtitle: Text(
                        'Fare ₹${stop.fare}',
                      ),
                      trailing: isCurrent
                          ? const Icon(
                              Icons.location_on,
                              color: AppTheme.accent,
                            )
                          : null,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            GradientButton(
              label: 'Share Location',
              icon: Icons.share_location,
              onPressed: () => _shareLocation(context, booking, bus),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () => _contactSupport(context),
              icon: const Icon(Icons.support_agent),
              label: const Text('Contact Support'),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _BookingStatusBanner extends StatelessWidget {
  const _BookingStatusBanner({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (booking.status) {
      BookingStatus.pending => (const Color(0xFFF5A623), Icons.hourglass_top_rounded, 'Waiting for driver to confirm'),
      BookingStatus.confirmed => (const Color(0xFF2ECC71), Icons.check_circle_rounded, 'Booking confirmed'),
      BookingStatus.rejected => (const Color(0xFFE5484D), Icons.cancel_rounded, 'Booking was declined'),
      BookingStatus.cancelled => (const Color(0xFFE5484D), Icons.cancel_rounded, 'Booking cancelled'),
      BookingStatus.completed => (AppTheme.accent, Icons.flag_circle_rounded, 'Trip completed'),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))),
        ],
      ),
    );
  }
}
