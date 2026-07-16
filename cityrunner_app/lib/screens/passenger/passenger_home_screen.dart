import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_runner_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/tracking_map.dart';

/// Passenger home: header -> current location / destination -> large map ->
/// floating bottom booking sheet overlaying the map, per the reference
/// hierarchy. The sheet is draggable so the buses list can expand without
/// leaving the map screen.
class PassengerHomeScreen extends StatelessWidget {
  const PassengerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final selectedBus = app.selectedBus;
    final liveBuses = app.visibleBuses.where((bus) => bus.isActive && bus.etaMinutes != null).toList();
    final fastestBus = liveBuses.isEmpty
        ? null
        : liveBuses.reduce((a, b) => a.etaMinutes! <= b.etaMinutes! ? a : b);

    return PhoneFrame(
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: _Header(app: app),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _LocationCard(),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    child: TrackingMap(
                      buses: app.visibleBuses,
                      selectedBus: selectedBus,
                      viewerLocation: app.passengerLocation,
                      onLocate: () => context.read<AppProvider>().locatePassenger(),
                      locateLabel: 'Locate',
                      height: null,
                      borderRadius: AppTheme.radiusCard,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (fastestBus != null)
            Positioned(
              top: 205,
              right: 40,
              child: _EtaBubble(bus: fastestBus),
            ),
          _BookingSheet(app: app, selectedBus: selectedBus),
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

class _EtaBubble extends StatelessWidget {
  const _EtaBubble({required this.bus});

  final BusState bus;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .82),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.accent.withValues(alpha: .55)),
        ),
        child: Text(
          '${bus.etaMinutes} min · ${bus.name}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.app});

  final AppProvider app;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.accent,
          child: Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome Back', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
              Text(app.passengerUser?.phoneNumber ?? 'Passenger', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(color: AppTheme.panel, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF262626))),
          child: IconButton(
            onPressed: () => _showTripUpdates(context),
            icon: const Icon(Icons.notifications_none, size: 20),
          ),
        ),
      ],
    );
  }

  void _showTripUpdates(BuildContext context) {
    final booking = context.read<AppProvider>().currentBooking;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trip Updates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            if (booking == null)
              const Text(
                "You don't have an active booking yet — book a seat to see live updates here.",
                style: TextStyle(color: AppTheme.muted),
              )
            else
              CityPanel(
                child: Row(
                  children: [
                    Icon(
                      switch (booking.status) {
                        BookingStatus.confirmed => Icons.check_circle_rounded,
                        BookingStatus.rejected || BookingStatus.cancelled => Icons.cancel_rounded,
                        _ => Icons.hourglass_top_rounded,
                      },
                      color: AppTheme.accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${booking.busName} · ${booking.status.name[0].toUpperCase()}${booking.status.name.substring(1)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (context.read<AppProvider>().passengerToken != null)
              TextButton.icon(
                onPressed: () async {
                  await context.read<AppProvider>().logout(UserRole.passenger);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              )
            else
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.pushNamed(context, AppRoutes.passengerPhone);
                },
                icon: const Icon(Icons.phone),
                label: const Text('Sign in to save trips'),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final destination = app.selectedBus?.stops.isNotEmpty == true ? app.selectedBus!.stops.last.name : 'Choose Destination';
    return CityPanel(
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.my_location, color: AppTheme.accent, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Current Location', style: TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [SizedBox(width: 8), Expanded(child: Divider(color: Color(0xFF2B2B2B), height: 1))]),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(destination, style: const TextStyle(fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right, color: AppTheme.muted, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

/// Floating bottom sheet: drag up to reveal the full buses / fare / payment
/// list, matching "bottom sheet overlays map, never stacked below it".
class _BookingSheet extends StatelessWidget {
  const _BookingSheet({required this.app, required this.selectedBus});

  final AppProvider app;
  final BusState? selectedBus;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.34,
      maxChildSize: 0.86,
      snap: true,
      snapSizes: const [0.34, 0.86],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusSheet)),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, -6))],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.activity),
                  icon: const Icon(Icons.history),
                  label: const Text('Activity'),
                ),
              ),
              const SectionTitle(title: 'Available Buses', subtitle: 'Choose your preferred route'),
              const SizedBox(height: 14),
              if (app.visibleBuses.isEmpty)
                const CityPanel(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No buses available', style: TextStyle(color: AppTheme.muted))),
                  ),
                )
              else
                ...app.visibleBuses.map(
                  (bus) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      onTap: () => app.selectBus(bus.id),
                      child: CityPanel(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.directions_bus, color: bus.id == selectedBus?.id ? AppTheme.accent : AppTheme.muted),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(bus.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text(bus.routeName, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (bus.id == selectedBus?.id) const Icon(Icons.check_circle, color: AppTheme.accent),
                              ],
                            ),
                            if (app.visibleBuses.where((item) => item.etaMinutes != null).isNotEmpty &&
                                bus.etaMinutes == app.visibleBuses.where((item) => item.etaMinutes != null).map((item) => item.etaMinutes!).reduce((a, b) => a < b ? a : b))
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Chip(
                                    avatar: Icon(Icons.bolt, color: AppTheme.accent, size: 16),
                                    label: Text('Fastest'),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(child: StatTile(label: 'Seats', value: '${bus.availableSeats}/${bus.seatCapacity}', icon: Icons.event_seat)),
                                const SizedBox(width: 10),
                                Expanded(child: StatTile(label: 'ETA', value: '${bus.etaMinutes ?? '--'} min', icon: Icons.timer)),
                                const SizedBox(width: 10),
                                Expanded(child: StatTile(label: 'Fare', value: '₹${bus.stops.isEmpty ? 0 : bus.stops.map((stop) => stop.fare).reduce((a, b) => a + b)}', icon: Icons.payments_outlined)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Fare Details', subtitle: 'Estimated trip price'),
              const SizedBox(height: 12),
              CityPanel(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated Fare', style: TextStyle(color: AppTheme.muted)),
                    Builder(
                      builder: (context) {
                        final selectedBusValue = selectedBus;
                        final fareText = selectedBusValue == null
                            ? '₹ --'
                            : '₹ ${selectedBusValue.stops.isNotEmpty ? selectedBusValue.stops.first.fare : 50}';
                        return Text(
                          fareText,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionTitle(title: 'Payment Method'),
              const SizedBox(height: 12),
              const CityPanel(
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: AppTheme.accent),
                    SizedBox(width: 12),
                    Expanded(child: Text('Wallet / UPI')),
                    Icon(Icons.chevron_right, color: AppTheme.muted),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              GradientButton(
                label: 'View Seats',
                icon: Icons.confirmation_number,
                onPressed: selectedBus == null
                    ? null
                    : () => Navigator.pushNamed(context, AppRoutes.seatSelection),
              ),
            ],
          ),
        );
      },
    );
  }
}
