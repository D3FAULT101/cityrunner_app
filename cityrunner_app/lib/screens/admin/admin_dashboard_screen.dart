import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/city_runner_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_chrome.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final overview = app.adminOverview;

    return PhoneFrame(
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: context.read<AppProvider>().refreshAdmin,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: AppTheme.panel, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF262626))),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Administrator', style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                          Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ConnectionDot(connected: app.adminSocketConnected),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: app.adminToken == null
                          ? null
                          : () => Navigator.pushNamed(context, AppRoutes.notifications),
                      icon: const Icon(Icons.notifications_none),
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: () async {
                        await context.read<AppProvider>().logout(
                          UserRole.admin,
                        );
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.roleSelection,
                          (_) => false,
                        );
                      },
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (app.adminToken == null)
                  _LoginRequired(
                    onLogin: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (_) => false,
                      arguments: UserRole.admin,
                    ),
                  )
                else if (overview == null)
                  CityPanel(
                    child: Column(
                      children: [
                        const Text('Admin data is not loaded yet.'),
                        const SizedBox(height: 12),
                        GradientButton(
                          label: 'Refresh',
                          icon: Icons.refresh,
                          onPressed: () =>
                              context.read<AppProvider>().refreshAdmin(),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _InlineStat(
                          label: 'Total Buses',
                          value: '${overview.buses.length}',
                          icon: Icons.directions_bus,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InlineStat(
                          label: 'Live Buses',
                          value: '${overview.buses.where((b) => b.isActive).length}',
                          icon: Icons.wifi_tethering,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _InlineStat(
                          label: 'Total Drivers',
                          value: '${overview.drivers.length}',
                          icon: Icons.badge,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InlineStat(
                          label: 'Assigned Drivers',
                          value: '${overview.drivers.where((d) => d.assignedBusName != null).length}',
                          icon: Icons.assignment_turned_in,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionTitle(title: 'Quick Actions'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          label: 'Add Bus',
                          icon: Icons.add_road,
                          busy: app.busyAction == 'create-bus',
                          onPressed: () => _showCreateBusDialog(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: app.busyAction == 'create-driver'
                              ? null
                              : () => _showCreateDriverDialog(
                                  context,
                                  overview.buses,
                                ),
                          icon: const Icon(Icons.person_add_alt),
                          label: const Text('Add Driver'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionTitle(
                    title: 'Fleet',
                    subtitle: 'Live buses returned by the backend.',
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.fleetMap),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('View All on Map'),
                    ),
                  ),
                  if (overview.buses.isEmpty)
                    const CityPanel(child: Text('No buses yet.'))
                  else
                    ...overview.buses.map(
                      (bus) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BusCard(bus: bus),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const SectionTitle(
                    title: 'Drivers',
                    subtitle: 'Driver accounts and assignments.',
                  ),
                  const SizedBox(height: 12),
                  if (overview.drivers.isEmpty)
                    const CityPanel(child: Text('No drivers yet.'))
                  else
                    ...overview.drivers.map(
                      (driver) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DriverCard(
                          driver: driver,
                          onResetPassword: () =>
                              _showResetPasswordDialog(context, driver),
                          onRemove: () =>
                              _showRemoveDriverDialog(context, driver),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          CitySnackHost(
            message: app.errorMessage ?? app.successMessage,
            isError: app.errorMessage != null,
            onDismiss: () => context.read<AppProvider>().clearMessages(),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateBusDialog(BuildContext context) async {
    final name = TextEditingController();
    final registration = TextEditingController();
    final route = TextEditingController(text: 'Gangtok -> Ranipool');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add Bus'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Bus name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: registration,
                decoration: const InputDecoration(
                  labelText: 'Registration number',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: route,
                decoration: const InputDecoration(labelText: 'Route name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await context.read<AppProvider>().createBus(
                  name.text.trim(),
                  registration.text.trim(),
                  route.text.trim(),
                );
                if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      );
    } finally {
      name.dispose();
      registration.dispose();
      route.dispose();
    }
  }

  Future<void> _showCreateDriverDialog(
    BuildContext context,
    List<BusState> buses,
  ) async {
    final username = TextEditingController();
    final displayName = TextEditingController();
    final password = TextEditingController();
    int? assignedBusId;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Add Driver'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: username,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: displayName,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: assignedBusId,
                    decoration: const InputDecoration(
                      labelText: 'Assigned bus',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No bus'),
                      ),
                      ...buses.map(
                        (bus) => DropdownMenuItem<int?>(
                          value: bus.id,
                          child: Text(
                            '${bus.name} (${bus.registrationNumber})',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => assignedBusId = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final ok = await context.read<AppProvider>().createDriver(
                    username.text.trim(),
                    displayName.text.trim(),
                    password.text,
                    assignedBusId,
                  );
                  if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Create'),
              ),
            ],
          ),
        ),
      );
    } finally {
      username.dispose();
      displayName.dispose();
      password.dispose();
    }
  }

  Future<void> _showResetPasswordDialog(
    BuildContext context,
    DriverSummary driver,
  ) async {
    final password = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Reset ${driver.displayName}'),
          content: TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await context
                    .read<AppProvider>()
                    .resetDriverPassword(driver.id, password.text);
                if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Reset'),
            ),
          ],
        ),
      );
    } finally {
      password.dispose();
    }
  }

  Future<void> _showRemoveDriverDialog(
    BuildContext context,
    DriverSummary driver,
  ) async {
    final adminPassword = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Remove ${driver.displayName}?'),
          content: TextField(
            controller: adminPassword,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Admin password'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await context.read<AppProvider>().removeDriver(
                  driver.id,
                  adminPassword.text,
                );
                if (ok && dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    } finally {
      adminPassword.dispose();
    }
  }
}

class _BusCard extends StatelessWidget {
  const _BusCard({required this.bus});

  final BusState bus;

  @override
  Widget build(BuildContext context) {
    return CityPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      bus.registrationNumber,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                bus.isActive ? 'Active' : 'Offline',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(bus.routeName, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 10),
          Text(
            '${bus.availableSeats}/${bus.seatCapacity} seats available',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.onResetPassword,
    required this.onRemove,
  });

  final DriverSummary driver;
  final VoidCallback onResetPassword;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return CityPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      driver.username,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (driver.mustChangePassword)
                const Icon(Icons.lock_reset, color: AppTheme.accent),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            driver.assignedBusName ?? 'No assigned bus',
            style: const TextStyle(color: AppTheme.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onResetPassword,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CityPanel(
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return CityPanel(
      child: Column(
        children: [
          const Icon(Icons.lock_outline, color: AppTheme.accent, size: 36),
          const SizedBox(height: 12),
          const Text('Admin login required.'),
          const SizedBox(height: 14),
          GradientButton(label: 'Login', icon: Icons.login, onPressed: onLogin),
        ],
      ),
    );
  }
}
