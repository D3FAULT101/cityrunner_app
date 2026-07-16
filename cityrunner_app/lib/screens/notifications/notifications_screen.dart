import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_runner_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppProvider>().refreshNotifications();
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final fallback = app.selectedRole == UserRole.admin ? AppRoutes.adminDashboard : AppRoutes.driverDashboard;
    final sorted = [...app.notifications]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return PhoneFrame(
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => AppRouter.goBack(context, fallbackRoute: fallback),
                      icon: const Icon(Icons.arrow_back_ios_new),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () => context.read<AppProvider>().refreshNotifications(),
                        child: sorted.isEmpty
                            ? ListView(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                children: const [
                                  SizedBox(height: 80),
                                  Center(
                                    child: Text(
                                      "You're all caught up.",
                                      style: TextStyle(color: AppTheme.muted),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                                itemCount: sorted.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final notification = sorted[index];
                                  return _NotificationCard(
                                    notification: notification,
                                    onTap: notification.isRead
                                        ? null
                                        : () => context.read<AppProvider>().markNotificationRead(notification.id),
                                  );
                                },
                              ),
                      ),
              ),
            ],
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  IconData get _icon => switch (notification.kind) {
        'incoming_booking' => Icons.directions_bus_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: CityPanel(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: notification.isRead
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, color: notification.isRead ? AppTheme.muted : AppTheme.accent, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: notification.isRead ? AppTheme.muted : AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(notification.body, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(_relativeTime(notification.createdAt), style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 11)),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().toUtc().difference(time.toUtc());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
