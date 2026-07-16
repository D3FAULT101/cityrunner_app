import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';

class PassengerOtpScreen extends StatefulWidget {
  const PassengerOtpScreen({super.key});

  @override
  State<PassengerOtpScreen> createState() => _PassengerOtpScreenState();
}

class _PassengerOtpScreenState extends State<PassengerOtpScreen> {
  final _code = TextEditingController();

  @override
  void dispose() { _code.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final phone = ModalRoute.of(context)?.settings.arguments as String? ?? '';
    return PhoneFrame(child: Stack(children: [
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconButton(onPressed: () => AppRouter.goBack(context, fallbackRoute: AppRoutes.passengerPhone), icon: const Icon(Icons.arrow_back_ios_new)),
          const SizedBox(height: 20),
          const Text('Enter verification code', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('We sent a 6-digit code to $phone', style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 28),
          TextField(controller: _code, maxLength: 6, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 10), decoration: const InputDecoration(counterText: '', hintText: '000000')),
          const SizedBox(height: 16),
          GradientButton(label: 'Verify', icon: Icons.verified_outlined, busy: app.busyAction == 'verify-passenger-otp', onPressed: () async {
            final ok = await context.read<AppProvider>().verifyPassengerOtp(phone, _code.text);
            if (!context.mounted || !ok) return;
            Navigator.pushNamedAndRemoveUntil(context, AppRoutes.passengerHome, (_) => false);
          }),
        ]),
      ),
      CitySnackHost(message: app.errorMessage ?? app.successMessage, isError: app.errorMessage != null, onDismiss: () => context.read<AppProvider>().clearMessages()),
    ]));
  }
}
