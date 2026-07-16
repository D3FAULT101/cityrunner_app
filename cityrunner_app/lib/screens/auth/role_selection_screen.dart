import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_runner_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/brand_widgets.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return PhoneFrame(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () => AppRouter.goBack(context, fallbackRoute: AppRoutes.onboarding),
              icon: const Icon(Icons.arrow_back_ios_new),
            ),

            const SizedBox(height: 12),

            const Center(
              child: BrandMark(),
            ),

            const SizedBox(height: 40),

            const Text(
              "Choose Your Role",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Select how you want to use CityRunner",
              style: TextStyle(
                color: AppTheme.muted,
              ),
            ),

            const SizedBox(height: 30),

            _RoleCard(
              title: 'Passenger',
              subtitle: 'Book buses, track rides and manage tickets',
              icon: Icons.person,
              color: AppTheme.accent,
              onTap: () {
                app.selectRole(UserRole.passenger);

                Navigator.pushNamed(context, AppRoutes.passengerPhone);
              },
            ),

            const SizedBox(height: 16),

            _RoleCard(
              title: 'Driver',
              subtitle: 'Manage routes, trips and passengers',
              icon: Icons.drive_eta,
              color: Colors.green,
              onTap: () {
                app.selectRole(UserRole.driver);

                if (app.driverToken == null) {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.login,
                    arguments: UserRole.driver,
                  );
                } else {
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.driverDashboard,
                  );
                }
              },
            ),

            const SizedBox(height: 40),

            const Text(
              "Management",
              style: TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            _RoleCard(
              title: 'Admin',
              subtitle: 'Fleet and system management',
              icon: Icons.admin_panel_settings,
              color: Colors.blue,
              compact: true,
              onTap: () {
                app.selectRole(UserRole.admin);

                if (app.adminToken == null) {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.login,
                    arguments: UserRole.admin,
                  );
                } else {
                  Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.adminDashboard,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(compact ? 16 : 20),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF2A2A2A),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 54 : 64,
              height: compact ? 54 : 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                icon,
                color: color,
                size: compact ? 28 : 34,
              ),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 16 : 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: AppTheme.muted,
            ),
          ],
        ),
      ),
    );
  }
}
