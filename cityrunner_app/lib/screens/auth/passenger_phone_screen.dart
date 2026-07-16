import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';

class PassengerPhoneScreen extends StatefulWidget {
  const PassengerPhoneScreen({super.key});

  @override
  State<PassengerPhoneScreen> createState() => _PassengerPhoneScreenState();
}

class _PassengerPhoneScreenState extends State<PassengerPhoneScreen> {
  final _phone = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return PhoneFrame(
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconButton(onPressed: () => AppRouter.goBack(context, fallbackRoute: AppRoutes.roleSelection), icon: const Icon(Icons.arrow_back_ios_new)),
            const SizedBox(height: 20),
            const Icon(Icons.phone_rounded, color: AppTheme.accent, size: 44),
            const SizedBox(height: 18),
            const Text('Continue with your phone', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('Save your trips and view your activity across devices.', style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 28),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined), hintText: '+91 98765 43210')),
            const SizedBox(height: 16),
            GradientButton(label: 'Send OTP', icon: Icons.sms_outlined, busy: app.busyAction == 'request-passenger-otp', onPressed: () async {
              final phone = _phone.text.trim();
              final ok = await context.read<AppProvider>().requestPassengerOtp(phone);
              if (!context.mounted || !ok) return;
              Navigator.pushNamed(context, AppRoutes.passengerOtp, arguments: phone);
            }),
            const SizedBox(height: 14),
            Center(child: TextButton(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.passengerHome, (_) => false), child: const Text('Continue as guest'))),
          ]),
        ),
        CitySnackHost(message: app.errorMessage ?? app.successMessage, isError: app.errorMessage != null, onDismiss: () => context.read<AppProvider>().clearMessages()),
      ]),
    );
  }
}
