import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentMethodOption {
  const _PaymentMethodOption(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethod = 'upi';

  static const _methods = [
    _PaymentMethodOption('upi', 'UPI', Icons.qr_code_rounded),
    _PaymentMethodOption('card', 'Credit / Debit Card', Icons.credit_card_rounded),
    _PaymentMethodOption('wallet', 'Wallets', Icons.account_balance_wallet_rounded),
    _PaymentMethodOption('netbanking', 'Net Banking', Icons.account_balance_rounded),
  ];

  Future<void> _payNow(BuildContext context) async {
    final app = context.read<AppProvider>();
    final bus = app.selectedBus;
    if (bus == null || app.draftPickupStopId == null || app.draftDestinationStopId == null) return;

    final success = await app.createBooking(
      busId: bus.id,
      seatIds: app.draftSeatIds,
      pickupStopId: app.draftPickupStopId!,
      destinationStopId: app.draftDestinationStopId!,
      paymentMethod: _selectedMethod,
    );

    if (!context.mounted) return;
    if (success) {
      Navigator.pushReplacementNamed(context, AppRoutes.bookingConfirmation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final bus = app.selectedBus;

    final seatLabels = bus == null
        ? const <String>[]
        : bus.seats.where((s) => app.draftSeatIds.contains(s.id)).map((s) => s.label).toList();

    String? stopName(int? stopId) {
      if (bus == null || stopId == null) return null;
      for (final stop in bus.stops) {
        if (stop.id == stopId) return stop.name;
      }
      return null;
    }

    final pickupName = stopName(app.draftPickupStopId);
    final destinationName = stopName(app.draftDestinationStopId);

    var farePerSeat = 0;
    if (bus != null && app.draftPickupStopId != null && app.draftDestinationStopId != null) {
      final stops = [...bus.stops]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      var cumulative = 0;
      var pickupCumulative = 0;
      var destinationCumulative = 0;
      for (final stop in stops) {
        cumulative += stop.fare;
        if (stop.id == app.draftPickupStopId) pickupCumulative = cumulative;
        if (stop.id == app.draftDestinationStopId) destinationCumulative = cumulative;
      }
      final rawFare = destinationCumulative - pickupCumulative;
      farePerSeat = rawFare < 0 ? 0 : rawFare;
    }
    final total = farePerSeat * seatLabels.length;
    final busy = app.busyAction == 'create-booking';

    return PhoneFrame(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
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
                      child: Text('Payment Method', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                CityPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bus?.name ?? 'Bus', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 6),
                      _SummaryRow(icon: Icons.trip_origin, label: pickupName ?? '—'),
                      const SizedBox(height: 6),
                      _SummaryRow(icon: Icons.flag_rounded, label: destinationName ?? '—'),
                      const SizedBox(height: 6),
                      _SummaryRow(
                        icon: Icons.event_seat_rounded,
                        label: seatLabels.isEmpty ? 'No seats selected' : 'Seat${seatLabels.length > 1 ? 's' : ''} ${seatLabels.join(', ')}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionTitle(title: 'Choose Payment Method'),
                const SizedBox(height: 12),
                CityPanel(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final method in _methods) ...[
                        _MethodTile(
                          option: method,
                          selected: _selectedMethod == method.id,
                          onTap: () => setState(() => _selectedMethod = method.id),
                        ),
                        if (method != _methods.last) const Divider(color: Color(0xFF262626), height: 1),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                decoration: const BoxDecoration(
                  color: AppTheme.background,
                  border: Border(top: BorderSide(color: Color(0xFF262626))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Amount', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                          Text(
                            '₹$total',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.accent),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: GradientButton(
                        label: 'Pay Now',
                        icon: Icons.lock_rounded,
                        busy: busy,
                        onPressed: seatLabels.isEmpty ? null : () => _payNow(context),
                      ),
                    ),
                  ],
                ),
              ),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 13))),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.option, required this.selected, required this.onTap});

  final _PaymentMethodOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(option.icon, color: selected ? AppTheme.accent : AppTheme.muted, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTheme.text : AppTheme.muted,
                ),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppTheme.accent : const Color(0xFF525252),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
