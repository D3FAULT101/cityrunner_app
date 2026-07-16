import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 54 : 76,
          height: compact ? 54 : 76,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF343434)),
          ),
          child: const Icon(Icons.directions_bus_filled, color: Colors.white, size: 34),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CITY', style: TextStyle(fontSize: compact ? 18 : 25, fontWeight: FontWeight.w800)),
            Text(
              'RUNNER',
              style: TextStyle(color: AppTheme.accent, fontSize: compact ? 18 : 25, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ],
    );
  }
}

class BusHeroArt extends StatelessWidget {
  const BusHeroArt({super.key, this.size = 190});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.35,
      child: CustomPaint(painter: _BusPainter()),
    );
  }
}

class _BusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = Colors.white;
    final dark = Paint()..color = const Color(0xFF121212);
    final glass = Paint()..color = const Color(0xFF1E2529);
    final line = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .25, size.height * .05, size.width * .5, size.height * .88),
      const Radius.circular(22),
    );
    canvas.drawRRect(rect, body);
    canvas.drawRRect(rect, line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .31, size.height * .55, size.width * .38, size.height * .18),
        const Radius.circular(12),
      ),
      glass,
    );
    canvas.drawRect(Rect.fromLTWH(size.width * .35, size.height * .13, size.width * .3, size.height * .27), line);
    canvas.drawRect(Rect.fromLTWH(size.width * .42, size.height * .43, size.width * .16, size.height * .05), line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .2, size.height * .62, size.width * .08, size.height * .2), const Radius.circular(6)),
      dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .72, size.height * .62, size.width * .08, size.height * .2), const Radius.circular(6)),
      dark,
    );
    canvas.drawCircle(Offset(size.width * .36, size.height * .84), 6, dark);
    canvas.drawCircle(Offset(size.width * .64, size.height * .84), 6, dark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
