import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/tracking_map.dart';

class FleetMapScreen extends StatelessWidget {
  const FleetMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return PhoneFrame(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Row(children: [IconButton(onPressed: () => AppRouter.goBack(context, fallbackRoute: AppRoutes.adminDashboard), icon: const Icon(Icons.arrow_back_ios_new)), const SizedBox(width: 8), const Expanded(child: Text('Fleet map', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))), Text('${app.adminOverview?.buses.length ?? 0} buses', style: const TextStyle(color: AppTheme.muted))])),
      Expanded(child: Padding(padding: const EdgeInsets.all(16), child: TrackingMap(buses: app.adminOverview?.buses ?? const [], selectedBus: null, viewerLocation: null, onLocate: () => context.read<AppProvider>().refreshAdmin(), locateLabel: 'Refresh', height: null, borderRadius: AppTheme.radiusCard))),
    ]));
  }
}
