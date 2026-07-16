import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_runner_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = (ModalRoute.of(context)?.settings.arguments as UserRole?) ?? context.watch<AppProvider>().selectedRole;
    final app = context.watch<AppProvider>();
    return PhoneFrame(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  role == UserRole.admin ? 'Admin Login' : 'Welcome Back',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text('Login to continue', style: TextStyle(color: AppTheme.muted)),
                const SizedBox(height: 28),
                TextField(
                  controller: _username,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.mail_outline), hintText: 'Email or Phone Number'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline),
                    hintText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _showForgotPasswordInfo(context, role),
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 12),
                GradientButton(
                  label: 'Login',
                  icon: Icons.login,
                  busy: app.busyAction == 'login',
                  onPressed: () async {
                    final ok = await context.read<AppProvider>().login(_username.text, _password.text, role);
                    if (!context.mounted || !ok) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      role == UserRole.driver ? AppRoutes.driverDashboard : AppRoutes.adminDashboard,
                      (_) => false,
                    );
                  },
                ),
                const SizedBox(height: 22),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFF2A2A2A))),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR', style: TextStyle(color: AppTheme.muted))),
                    Expanded(child: Divider(color: Color(0xFF2A2A2A))),
                  ],
                ),
                const SizedBox(height: 18),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Social(icon: Icons.g_mobiledata),
                    _Social(icon: Icons.apple),
                    _Social(icon: Icons.phone_android),
                  ],
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.roleSelection),
                  child: const Text("Don't have an account? Sign Up"),
                ),
              ],
            ),
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

  void _showForgotPasswordInfo(BuildContext context, UserRole role) {
    final roleLabel = role == UserRole.admin ? 'admin' : 'driver';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forgot Password?'),
        content: Text(
          role == UserRole.admin
              ? "Admin passwords can't be self-reset yet. Contact another admin or your backend operator to reset it directly in the database."
              : "Driver passwords are reset by an admin. Ask your fleet admin to reset your $roleLabel password from the Admin Dashboard \u2014 you'll be asked to set a new one on your next login.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Got it')),
        ],
      ),
    );
  }
}

class _Social extends StatelessWidget {
  const _Social({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(color: AppTheme.elevated, shape: BoxShape.circle),
      child: Icon(icon),
    );
  }
}
