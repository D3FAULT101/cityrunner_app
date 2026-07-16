import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/brand_widgets.dart';

/// Splash never auto-navigates. The person taps "Let's Go" when ready.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, .08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PhoneFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
        child: Column(
          children: [
            const Spacer(flex: 2),
            FadeTransition(
              opacity: _fade,
              child: Hero(
                tag: 'city-runner-bus',
                child: const BusHeroArt(size: 190),
              ),
            ),
            const SizedBox(height: 20),
            SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, fontFamily: 'Poppins'),
                        children: [
                          TextSpan(text: 'CITY', style: TextStyle(color: AppTheme.text)),
                          TextSpan(text: 'RUNNER', style: TextStyle(color: AppTheme.accent)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      AppConstants.tagline,
                      style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => Container(
                  width: index == 0 ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == 0 ? AppTheme.accent : Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.onboarding),
                icon: const Icon(Icons.arrow_forward, color: Colors.black87, size: 18),
                label: const Text("Let's Go"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
