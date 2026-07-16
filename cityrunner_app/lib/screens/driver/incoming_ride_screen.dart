import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';

class IncomingRideScreen extends StatelessWidget {
  const IncomingRideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final booking = app.pendingDriverBookings.isNotEmpty ? app.pendingDriverBookings.first : null;
    final busy = app.busyAction == 'respond-booking';

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
                      onPressed: () => AppRouter.goBack(context, fallbackRoute: AppRoutes.driverDashboard),
                      icon: const Icon(Icons.arrow_back_ios_new),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Incoming Ride', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                    if (app.pendingDriverBookings.length > 1)
                      Chip(label: Text('+${app.pendingDriverBookings.length - 1} more')),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('New ride request', style: TextStyle(color: AppTheme.muted, fontSize: 13)),
                const SizedBox(height: 20),
                if (booking == null)
                  const CityPanel(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No pending ride requests right now.', style: TextStyle(color: AppTheme.muted)),
                      ),
                    ),
                  )
                else ...[
                  CityPanel(
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: 150,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        child: const _RoutePreview(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  CityPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_rounded, color: AppTheme.accent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(booking.passengerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    '${booking.seats.length} seat${booking.seats.length > 1 ? 's' : ''} • ${booking.paymentMethod.toUpperCase()}',
                                    style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFF262626), height: 26),
                        _RouteRow(icon: Icons.trip_origin, label: 'Pickup', value: booking.pickupStopName ?? '—'),
                        const SizedBox(height: 10),
                        _RouteRow(icon: Icons.flag_rounded, label: 'Destination', value: booking.destinationStopName ?? '—'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(label: 'Fare', value: '₹${booking.fareTotal}', icon: Icons.payments_rounded),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatTile(
                          label: 'Distance',
                          value: booking.distanceKm == null ? '—' : '${booking.distanceKm!.toStringAsFixed(1)} km',
                          icon: Icons.route_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : () => context.read<AppProvider>().respondToBooking(booking.id, false),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFFE5484D)),
                          label: const Text('Reject', style: TextStyle(color: Color(0xFFE5484D))),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFE5484D))),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GradientButton(
                          label: 'Accept',
                          icon: Icons.check_rounded,
                          busy: busy,
                          onPressed: () => context.read<AppProvider>().respondToBooking(booking.id, true),
                        ),
                      ),
                    ],
                  ),
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

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lightweight decorative route preview (no live coordinates available for
/// a not-yet-accepted booking) — keeps the screen visually consistent with
/// the live tracking map elsewhere in the app.
class _RoutePreview extends StatelessWidget {
  const _RoutePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTheme.elevated,
      child: CustomPaint(painter: _DottedRoutePainter()),
    );
  }
}

class _DottedRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final start = Offset(size.width * 0.18, size.height * 0.7);
    final end = Offset(size.width * 0.82, size.height * 0.3);

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final total = (end - start).distance;
    final direction = (end - start) / total;
    var covered = 0.0;
    while (covered < total) {
      final segmentEnd = covered + dashWidth > total ? total : covered + dashWidth;
      canvas.drawLine(start + direction * covered, start + direction * segmentEnd, paint);
      covered += dashWidth + dashSpace;
    }

    final pointPaint = Paint()..color = AppTheme.accent;
    canvas.drawCircle(start, 6, pointPaint);
    canvas.drawCircle(end, 6, Paint()..color = AppTheme.text);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
