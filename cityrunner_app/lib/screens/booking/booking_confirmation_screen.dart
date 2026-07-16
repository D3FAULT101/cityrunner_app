import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_runner_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final booking = app.currentBooking;

    return PhoneFrame(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.passengerHome,
                        (route) => false,
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Booking Status', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (booking == null)
                  const CityPanel(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('No active booking.')),
                    ),
                  )
                else ...[
                  Center(child: _StatusBadge(status: booking.status)),
                  const SizedBox(height: 20),
                  CityPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.confirmation_number_rounded, color: AppTheme.accent, size: 18),
                            const SizedBox(width: 8),
                            Text('Code ${booking.publicCode}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const Divider(color: Color(0xFF262626), height: 28),
                        _DetailRow(label: 'Bus', value: booking.busName),
                        _DetailRow(label: 'Route', value: booking.routeName),
                        _DetailRow(label: 'From', value: booking.pickupStopName ?? '—'),
                        _DetailRow(label: 'To', value: booking.destinationStopName ?? '—'),
                        _DetailRow(label: 'Seats', value: booking.seats.map((s) => s.label).join(', ')),
                        if (booking.distanceKm != null)
                          _DetailRow(label: 'Distance', value: '${booking.distanceKm!.toStringAsFixed(1)} km'),
                        _DetailRow(label: 'Payment', value: booking.paymentMethod.toUpperCase()),
                        const Divider(color: Color(0xFF262626), height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Paid', style: TextStyle(color: AppTheme.muted)),
                            Text(
                              '₹${booking.fareTotal}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.accent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StatusMessage(status: booking.status),
                  const SizedBox(height: 20),
                  if (booking.status == BookingStatus.confirmed || booking.status == BookingStatus.pending)
                    GradientButton(
                      label: 'Track My Bus',
                      icon: Icons.route,
                      onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.tracking),
                    ),
                  if (booking.status == BookingStatus.rejected || booking.status == BookingStatus.cancelled) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        context.read<AppProvider>().clearCurrentBooking();
                        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.passengerHome, (route) => false);
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Choose a Different Bus'),
                    ),
                  ],
                ],
              ],
            ),
          ),
          CitySnackHost(
            message: app.errorMessage,
            isError: true,
            onDismiss: () => context.read<AppProvider>().clearMessages(),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      BookingStatus.pending => (const Color(0xFFF5A623), Icons.hourglass_top_rounded, 'Waiting for Driver'),
      BookingStatus.confirmed => (const Color(0xFF2ECC71), Icons.check_circle_rounded, 'Booking Confirmed!'),
      BookingStatus.rejected => (const Color(0xFFE5484D), Icons.cancel_rounded, 'Booking Declined'),
      BookingStatus.cancelled => (const Color(0xFFE5484D), Icons.cancel_rounded, 'Booking Cancelled'),
      BookingStatus.completed => (AppTheme.accent, Icons.flag_circle_rounded, 'Trip Completed'),
    };
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 42),
        ),
        const SizedBox(height: 14),
        Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      BookingStatus.pending => 'Your seat is held. The driver will accept or decline shortly — this screen updates automatically.',
      BookingStatus.confirmed => 'Your seat is booked. Head to the pickup stop before the bus arrives.',
      BookingStatus.rejected => 'The driver couldn\'t take this booking. Your seat has been released — no charge was kept.',
      BookingStatus.cancelled => 'This booking was cancelled.',
      BookingStatus.completed => 'Thanks for riding with City Runner!',
    };
    return CityPanel(
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.muted, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppTheme.muted, fontSize: 13))),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
