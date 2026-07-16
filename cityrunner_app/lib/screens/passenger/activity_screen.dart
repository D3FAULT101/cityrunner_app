import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_runner_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final trips = app.passengerTripHistory;
    return PhoneFrame(child: Stack(children: [
      RefreshIndicator(
        onRefresh: context.read<AppProvider>().refreshTripHistory,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Row(children: [
            IconButton(onPressed: () => AppRouter.goBack(context, fallbackRoute: AppRoutes.passengerHome), icon: const Icon(Icons.arrow_back_ios_new)),
            const SizedBox(width: 8), const Expanded(child: Text('Activity', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 18),
          if (app.passengerToken == null)
            CityPanel(child: Column(children: [const Icon(Icons.lock_outline, color: AppTheme.accent, size: 36), const SizedBox(height: 12), const Text('Sign in to see your trip history.'), const SizedBox(height: 12), GradientButton(label: 'Sign in', icon: Icons.phone, onPressed: () => Navigator.pushNamed(context, AppRoutes.passengerPhone))]))
          else if (trips.isEmpty)
            const CityPanel(child: Padding(padding: EdgeInsets.all(18), child: Text('No trips yet. Your signed-in bookings will appear here.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted))))
          else ...[
            const Text('Recent trip', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            _TripCard(booking: trips.first, prominent: true),
            if (trips.length > 1) ...[const SizedBox(height: 22), const Text('Earlier trips', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 10), ...trips.skip(1).map((trip) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _TripCard(booking: trip)))],
          ],
        ]),
      ),
      CitySnackHost(message: app.errorMessage ?? app.successMessage, isError: app.errorMessage != null, onDismiss: () => context.read<AppProvider>().clearMessages()),
    ]));
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.booking, this.prominent = false});
  final Booking booking;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final cancelled = booking.status == BookingStatus.cancelled || booking.status == BookingStatus.rejected;
    final color = cancelled ? const Color(0xFFE5484D) : booking.status == BookingStatus.confirmed || booking.status == BookingStatus.completed ? Colors.greenAccent : AppTheme.accent;
    return CityPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (prominent) Container(height: 62, decoration: BoxDecoration(color: AppTheme.elevated, borderRadius: BorderRadius.circular(12)), child: const Center(child: Icon(Icons.route_rounded, color: AppTheme.accent, size: 30))),
      if (prominent) const SizedBox(height: 14),
      Row(children: [const Icon(Icons.directions_bus, color: AppTheme.accent), const SizedBox(width: 10), Expanded(child: Text(booking.destinationStopName ?? booking.busName, style: const TextStyle(fontWeight: FontWeight.w800))), Text(booking.status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800))]),
      const SizedBox(height: 8), Text('${booking.pickupStopName ?? 'Start'} → ${booking.destinationStopName ?? 'Destination'}', style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
      const SizedBox(height: 8), Row(children: [Expanded(child: Text('${booking.createdAt.day}/${booking.createdAt.month}/${booking.createdAt.year}', style: const TextStyle(color: AppTheme.muted, fontSize: 12))), Text('₹${cancelled ? 0 : booking.fareTotal}', style: const TextStyle(fontWeight: FontWeight.w800))]),
      const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: OutlinedButton.icon(onPressed: () => _rebook(context), icon: const Icon(Icons.replay, size: 17), label: const Text('Rebook'))),
    ]));
  }

  void _rebook(BuildContext context) {
    final app = context.read<AppProvider>();
    final bus = app.visibleBuses.where((bus) => bus.id == booking.busId).firstOrNull;
    if (bus == null || booking.pickupStopName == null || booking.destinationStopName == null) return;
    final pickup = bus.stops.where((stop) => stop.name == booking.pickupStopName).firstOrNull;
    final destination = bus.stops.where((stop) => stop.name == booking.destinationStopName).firstOrNull;
    final seats = booking.seats.map((seat) => seat.id).where((id) => bus.seats.any((seat) => seat.id == id && !seat.isBooked)).toList();
    if (pickup == null || destination == null || seats.length != booking.seats.length) return;
    app.selectBus(bus.id);
    app.setDraftBooking(seatIds: seats, pickupStopId: pickup.id, destinationStopId: destination.id);
    Navigator.pushNamed(context, AppRoutes.payment);
  }
}
