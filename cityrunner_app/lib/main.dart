import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'repositories/city_runner_repository.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CityRunnerApp());
}

class CityRunnerApp extends StatelessWidget {
  const CityRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(CityRunnerRepository(ApiService()))..bootstrap(),
      child: MaterialApp(
        title: 'City Runner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        navigatorKey: AppRouter.navigatorKey,
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRoutes.splash,
        builder: (context, child) => _AuthRedirector(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

class _AuthRedirector extends StatelessWidget {
  const _AuthRedirector({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AppProvider>().authRedirectRole;
    if (role != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final redirectRole = context.read<AppProvider>().consumeAuthRedirect();
        if (redirectRole == null) return;
        AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (_) => false,
          arguments: redirectRole,
        );
      });
    }
    return child;
  }
}
