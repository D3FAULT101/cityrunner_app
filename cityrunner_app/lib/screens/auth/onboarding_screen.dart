import 'package:flutter/material.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/brand_widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();

  int currentPage = 0;

  final List<_SlideData> slides = const [
    _SlideData(
      title: 'Track. Book. Ride.',
      subtitle:
          'Live tracking, easy booking and safe journeys across the city.',
      icon: Icons.route,
    ),
    _SlideData(
      title: 'Choose Your Route',
      subtitle:
          'Find available buses instantly and plan your trip effortlessly.',
      icon: Icons.location_on,
    ),
    _SlideData(
      title: 'Safe & Reliable Travel',
      subtitle:
          'Real-time updates, secure bookings and dependable transport.',
      icon: Icons.verified_user,
    ),
  ];

  bool get _isLastPage => currentPage == slides.length - 1;

  void _nextPage() {
    if (!_isLastPage) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushNamed(context, AppRoutes.roleSelection);
    }
  }

  void _skip() {
    Navigator.pushNamed(context, AppRoutes.roleSelection);
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Align(alignment: Alignment.centerLeft, child: BrandMark(compact: true)),

            const SizedBox(height: 20),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (value) {
                  setState(() {
                    currentPage = value;
                  });
                },
                itemCount: slides.length,
                itemBuilder: (context, index) {
                  final slide = slides[index];

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Stylized dark road map with a dotted route, echoing
                      // the reference onboarding art (pickup + destination
                      // pins joined by a dashed path) without needing a
                      // bitmap asset.
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CustomPaint(painter: _RoadMapPainter()),
                      ),

                      const SizedBox(height: 32),

                      Text(
                        slide.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        slide.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 64,
                  child: _isLastPage
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: _skip,
                          style: TextButton.styleFrom(foregroundColor: AppTheme.muted),
                          child: const Text('Skip'),
                        ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    slides.length,
                    (index) => Container(
                      width: currentPage == index ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: currentPage == index
                            ? AppTheme.accent
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: TextButton(
                    onPressed: _nextPage,
                    style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
                    child: Text(_isLastPage ? 'Get Started' : 'Next'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _RoadMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF232323)
      ..strokeWidth = 1.2;
    for (var i = 1; i < 6; i++) {
      final dx = size.width / 6 * i;
      final dy = size.height / 6 * i;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), grid);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), grid);
    }

    final routePaint = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .22, size.height * .28)
      ..cubicTo(size.width * .1, size.height * .55, size.width * .4, size.height * .5, size.width * .48, size.height * .68)
      ..cubicTo(size.width * .58, size.height * .9, size.width * .78, size.height * .78, size.width * .8, size.height * .3);

    // Dotted stroke, matching the design's "orange dotted route".
    const dashLength = 8.0;
    const gapLength = 6.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), routePaint);
        distance += dashLength + gapLength;
      }
    }

    _pin(canvas, Offset(size.width * .22, size.height * .28), Icons.directions_bus_filled, AppTheme.accent);
    _pin(canvas, Offset(size.width * .8, size.height * .3), Icons.location_on, Colors.redAccent);
  }

  void _pin(Canvas canvas, Offset center, IconData icon, Color color) {
    canvas.drawCircle(center, 16, Paint()..color = const Color(0xFF171717));
    canvas.drawCircle(center, 16, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    final painter = TextPainter(
      text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontFamily: icon.fontFamily, color: color, fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _RoadMapPainter oldDelegate) => false;
}

class _SlideData {
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}