import 'dart:math';

import '../../models/city_runner_models.dart';

double haversineDistanceKm(Coordinate a, Coordinate b) {
  const earthRadiusKm = 6371.0;
  double toRadians(double value) => value * pi / 180;
  final dLat = toRadians(b.lat - a.lat);
  final dLng = toRadians(b.lng - a.lng);
  final h = pow(sin(dLat / 2), 2) +
      cos(toRadians(a.lat)) * cos(toRadians(b.lat)) * pow(sin(dLng / 2), 2);
  return earthRadiusKm * 2 * atan2(sqrt(h), sqrt(1 - h));
}

String formatLastSeen(DateTime? value) {
  if (value == null) return 'Waiting for driver GPS';
  final diff = DateTime.now().toUtc().difference(value.toUtc()).inMinutes;
  if (diff < 1) return 'Updated just now';
  if (diff == 1) return 'Updated 1 min ago';
  return 'Updated $diff mins ago';
}
