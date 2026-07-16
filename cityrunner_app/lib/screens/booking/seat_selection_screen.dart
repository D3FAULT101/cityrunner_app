import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_runner_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/seat_grid.dart';

class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({super.key});

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  final Set<int> _selectedSeatIds = {};
  int? _pickupStopId;
  int? _destinationStopId;
  int? _initializedForBusId;

  void _initStopsIfNeeded(BusState bus) {
    if (_initializedForBusId == bus.id) return;
    final stops = [...bus.stops]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (stops.length >= 2) {
      _pickupStopId = stops.first.id;
      _destinationStopId = stops.last.id;
    }
    _initializedForBusId = bus.id;
  }

  /// Client-side estimate only — the backend computes the authoritative
  /// fare (per-leg fares summed between pickup and destination) when the
  /// booking is actually created.
  int _estimatedFarePerSeat(BusState bus) {
    if (_pickupStopId == null || _destinationStopId == null) return 0;
    final stops = [...bus.stops]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    var cumulative = 0;
    var pickupCumulative = 0;
    var destinationCumulative = 0;
    for (final stop in stops) {
      cumulative += stop.fare;
      if (stop.id == _pickupStopId) pickupCumulative = cumulative;
      if (stop.id == _destinationStopId) destinationCumulative = cumulative;
    }
    final fare = destinationCumulative - pickupCumulative;
    return fare < 0 ? 0 : fare;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final bus = app.selectedBus;
    if (bus != null) _initStopsIfNeeded(bus);

    final stopsSorted = bus == null ? const <Stop>[] : ([...bus.stops]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)));
    final fareEstimate = bus == null ? 0 : _estimatedFarePerSeat(bus);
    final totalEstimate = fareEstimate * _selectedSeatIds.length;
    final destinationBeforePickup = _pickupStopId != null &&
        _destinationStopId != null &&
        stopsSorted.indexWhere((s) => s.id == _pickupStopId) >=
            stopsSorted.indexWhere((s) => s.id == _destinationStopId);

    final canContinue = bus != null &&
        _selectedSeatIds.isNotEmpty &&
        _pickupStopId != null &&
        _destinationStopId != null &&
        !destinationBeforePickup;

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
                      child: Text(
                        'Select Your Seat',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (bus == null)
                  const CityPanel(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('Choose a bus first.')),
                    ),
                  )
                else ...[
                  CityPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bus.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(bus.routeName, style: const TextStyle(color: AppTheme.muted)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _InlineStat(
                                label: 'Available',
                                value: '${bus.availableSeats}',
                                icon: Icons.event_available,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _InlineStat(
                                label: 'Booked',
                                value: '${bus.bookedSeats}',
                                icon: Icons.event_busy,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle(title: 'Where are you headed?'),
                  const SizedBox(height: 12),
                  CityPanel(
                    child: Column(
                      children: [
                        _StopDropdown(
                          label: 'Pickup stop',
                          icon: Icons.trip_origin,
                          stops: stopsSorted,
                          value: _pickupStopId,
                          onChanged: (id) => setState(() => _pickupStopId = id),
                        ),
                        const Divider(color: Color(0xFF262626), height: 24),
                        _StopDropdown(
                          label: 'Destination stop',
                          icon: Icons.flag_rounded,
                          stops: stopsSorted,
                          value: _destinationStopId,
                          onChanged: (id) => setState(() => _destinationStopId = id),
                        ),
                        if (destinationBeforePickup) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Destination must be further along the route than pickup.',
                            style: TextStyle(color: Color(0xFFE5484D), fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle(
                    title: 'Seats',
                    subtitle: 'Tap to select. Selected seats are held for you once you continue.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      _Legend(color: AppTheme.elevated, label: 'Available'),
                      SizedBox(width: 14),
                      _Legend(color: AppTheme.accent, label: 'Selected'),
                      SizedBox(width: 14),
                      _Legend(color: Color(0xFF525252), label: 'Booked'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CityPanel(
                    child: SeatGrid(
                      seats: bus.seats,
                      readOnly: false,
                      selectedSeatIds: _selectedSeatIds,
                      maxSelectable: 6,
                      busyAction: app.busyAction,
                      onToggleSeat: (seatId) {
                        setState(() {
                          if (_selectedSeatIds.contains(seatId)) {
                            _selectedSeatIds.remove(seatId);
                          } else {
                            _selectedSeatIds.add(seatId);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (bus != null)
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
                              '₹$totalEstimate',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.accent),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: GradientButton(
                          label: 'Continue',
                          icon: Icons.arrow_forward,
                          onPressed: canContinue
                              ? () {
                                  context.read<AppProvider>().setDraftBooking(
                                        seatIds: _selectedSeatIds.toList(),
                                        pickupStopId: _pickupStopId!,
                                        destinationStopId: _destinationStopId!,
                                      );
                                  Navigator.pushNamed(context, AppRoutes.payment);
                                }
                              : null,
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

class _StopDropdown extends StatelessWidget {
  const _StopDropdown({
    required this.label,
    required this.icon,
    required this.stops,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final List<Stop> stops;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: value,
                  isExpanded: true,
                  dropdownColor: AppTheme.elevated,
                  style: const TextStyle(color: AppTheme.text, fontWeight: FontWeight.w700, fontSize: 15),
                  items: stops
                      .map((stop) => DropdownMenuItem<int>(value: stop.id, child: Text(stop.name)))
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF343434)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
      ],
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
