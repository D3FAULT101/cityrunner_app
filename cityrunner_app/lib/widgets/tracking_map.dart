import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../core/theme/app_theme.dart';
import '../models/city_runner_models.dart';
import 'app_chrome.dart';

/// Live tracking map rendered with flutter_map + OpenStreetMap raster tiles.
/// No API key required. Tiles are desaturated/inverted with a ColorFilter so
/// the map reads as a "dark map" consistent with the CityRunner design
/// system, without depending on a paid dark-tile provider.
class TrackingMap extends StatelessWidget {
  const TrackingMap({
    super.key,
    required this.buses,
    required this.selectedBus,
    required this.viewerLocation,
    required this.onLocate,
    required this.locateLabel,
    this.height = 260,
    this.borderRadius = 16,
  });

  final List<BusState> buses;
  final BusState? selectedBus;
  final Coordinate? viewerLocation;
  final VoidCallback onLocate;
  final String locateLabel;

  /// Fixed height for the map card. Pass `null` to have the map fill all
  /// space offered by the parent (e.g. inside an `Expanded` or
  /// `Positioned.fill`), which is how the passenger home screen renders a
  /// full-bleed map behind the floating booking sheet.
  final double? height;
  final double borderRadius;

  static const _fallbackCenter = ll.LatLng(27.3389, 88.6065); // Gangtok

  @override
  Widget build(BuildContext context) {
    final mapSurface = _DarkOsmMap(
      buses: buses,
      selectedBus: selectedBus,
      viewerLocation: viewerLocation,
      fallbackCenter: _fallbackCenter,
    );

    return CityPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned.fill(child: mapSurface),
              Positioned(
                right: 12,
                top: 12,
                child: FilledButton.icon(
                  onPressed: onLocate,
                  icon: const Icon(Icons.my_location, size: 17),
                  label: Text(locateLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: .72),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkOsmMap extends StatefulWidget {
  const _DarkOsmMap({
    required this.buses,
    required this.selectedBus,
    required this.viewerLocation,
    required this.fallbackCenter,
  });

  final List<BusState> buses;
  final BusState? selectedBus;
  final Coordinate? viewerLocation;
  final ll.LatLng fallbackCenter;

  @override
  State<_DarkOsmMap> createState() => _DarkOsmMapState();
}

/// Animates bus marker positions smoothly between updates instead of
/// snapping instantly, so the bus icon visibly glides toward the passenger
/// as real-time location pushes arrive over the WebSocket.
class _DarkOsmMapState extends State<_DarkOsmMap> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addListener(_onTick);

  Map<int, ll.LatLng> _from = {};
  Map<int, ll.LatLng> _to = {};
  Map<int, ll.LatLng> _displayed = {};

  @override
  void initState() {
    super.initState();
    _to = _extractPositions(widget.buses);
    _from = _to;
    _displayed = _to;
  }

  @override
  void didUpdateWidget(covariant _DarkOsmMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _extractPositions(widget.buses);
    if (!_positionsEqual(next, _to)) {
      _from = _displayed.isEmpty ? next : _displayed;
      _to = next;
      _controller.forward(from: 0);
    }
  }

  Map<int, ll.LatLng> _extractPositions(List<BusState> buses) {
    final map = <int, ll.LatLng>{};
    for (final bus in buses) {
      final position = bus.position;
      if (position != null) map[bus.id] = ll.LatLng(position.lat, position.lng);
    }
    return map;
  }

  bool _positionsEqual(Map<int, ll.LatLng> a, Map<int, ll.LatLng> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || other.latitude != entry.value.latitude || other.longitude != entry.value.longitude) {
        return false;
      }
    }
    return true;
  }

  void _onTick() {
    final t = Curves.easeInOut.transform(_controller.value);
    final next = <int, ll.LatLng>{};
    for (final entry in _to.entries) {
      final from = _from[entry.key] ?? entry.value;
      next[entry.key] = ll.LatLng(
        from.latitude + (entry.value.latitude - from.latitude) * t,
        from.longitude + (entry.value.longitude - from.longitude) * t,
      );
    }
    setState(() => _displayed = next);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.selectedBus;
    final hasRoute = bus != null && bus.route.isNotEmpty;
    final center = hasRoute
        ? ll.LatLng(bus.route.first.lat, bus.route.first.lng)
        : (widget.viewerLocation != null
            ? ll.LatLng(widget.viewerLocation!.lat, widget.viewerLocation!.lng)
            : widget.fallbackCenter);

    return ColorFiltered(
      // Inverts + desaturates the standard OSM raster tiles so we get a
      // free, no-API-key "dark map" look instead of light OSM tiles.
      colorFilter: const ColorFilter.matrix(<double>[
        -0.6, -0.2, -0.2, 0, 235,
        -0.2, -0.6, -0.2, 0, 235,
        -0.2, -0.2, -0.6, 0, 235,
        0, 0, 0, 1, 0,
      ]),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: hasRoute ? 12.5 : 12,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.cityrunner.app',
            maxZoom: 19,
          ),
          if (hasRoute)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: bus.route.map((p) => ll.LatLng(p.lat, p.lng)).toList(),
                  color: AppTheme.accent,
                  strokeWidth: 4,
                  pattern: const StrokePattern.dotted(),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final item in widget.buses)
                if (_displayed[item.id] != null)
                  Marker(
                    point: _displayed[item.id]!,
                    width: 42,
                    height: 42,
                    child: _BusMarker(
                      isSelected: bus != null && item.id == bus.id,
                    ),
                  ),
              if (hasRoute)
                for (final stop in bus.stops)
                  Marker(
                    point: ll.LatLng(stop.coordinate.lat, stop.coordinate.lng),
                    width: 26,
                    height: 26,
                    child: const _StopMarker(),
                  ),
              if (widget.viewerLocation != null)
                Marker(
                  point: ll.LatLng(widget.viewerLocation!.lat, widget.viewerLocation!.lng),
                  width: 22,
                  height: 22,
                  child: const _ViewerMarker(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated bus glyph that gently pulses, giving the "animated bus marker"
/// the design calls for without needing custom bitmap assets.
class _BusMarker extends StatefulWidget {
  const _BusMarker({required this.isSelected});

  final bool isSelected;

  @override
  State<_BusMarker> createState() => _BusMarkerState();
}

class _BusMarkerState extends State<_BusMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 1 + (_controller.value * 0.12);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: pulse,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withValues(alpha: .18),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isSelected ? AppTheme.accent : AppTheme.elevated,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: const Icon(Icons.directions_bus_filled, color: Colors.white, size: 16),
      ),
    );
  }
}

class _StopMarker extends StatelessWidget {
  const _StopMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.background,
        border: Border.all(color: AppTheme.accent, width: 2),
      ),
      child: const Icon(Icons.location_on, color: AppTheme.accent, size: 14),
    );
  }
}

class _ViewerMarker extends StatelessWidget {
  const _ViewerMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.lightBlueAccent,
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4)],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 12),
    );
  }
}
