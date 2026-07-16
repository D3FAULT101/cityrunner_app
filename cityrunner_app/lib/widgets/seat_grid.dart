import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/city_runner_models.dart';

class SeatGrid extends StatelessWidget {
  const SeatGrid({
    super.key,
    required this.seats,
    required this.readOnly,
    required this.onToggleSeat,
    required this.busyAction,
    this.selectedSeatIds = const {},
    this.maxSelectable,
  });

  final List<Seat> seats;
  final bool readOnly;
  final ValueChanged<int> onToggleSeat;
  final String? busyAction;

  /// Seat ids the passenger has picked (driver's own toggle usage leaves
  /// this empty since it only distinguishes booked/available).
  final Set<int> selectedSeatIds;

  /// If set, tapping an unselected seat is a no-op once this many seats are
  /// already selected (still allows deselecting).
  final int? maxSelectable;

  @override
  Widget build(BuildContext context) {
    final sorted = [...seats]..sort((a, b) => a.id.compareTo(b.id));
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final seat = sorted[index];
        final busy = busyAction == 'seat-${seat.id}';
        final isSelected = selectedSeatIds.contains(seat.id);
        final atCapacity = maxSelectable != null &&
            selectedSeatIds.length >= maxSelectable! &&
            !isSelected;
        final disabled = readOnly || busy || seat.isBooked || atCapacity;

        final Color color;
        final Color borderColor;
        if (seat.isBooked) {
          color = const Color(0xFF525252);
          borderColor = const Color(0xFF666666);
        } else if (isSelected) {
          color = AppTheme.accent;
          borderColor = AppTheme.accent;
        } else {
          color = AppTheme.elevated;
          borderColor = const Color(0xFF343434);
        }

        return InkWell(
          onTap: disabled ? null : () => onToggleSeat(seat.id),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    seat.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppTheme.text,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
