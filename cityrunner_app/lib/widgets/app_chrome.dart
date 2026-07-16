import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0D0D), Color(0xFF101010), Color(0xFF050505)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class CityPanel extends StatelessWidget {
  const CityPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626)),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 18, offset: Offset(0, 10))],
      ),
      child: child,
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFA229), AppTheme.accent]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon ?? Icons.arrow_forward, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
        ],
      ],
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CityPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small dot showing whether a WebSocket channel is live-connected
/// (green) or reconnecting (amber). Used on driver/admin dashboards.
class ConnectionDot extends StatelessWidget {
  const ConnectionDot({super.key, required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: connected ? 'Live updates connected' : 'Reconnecting…',
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: connected ? const Color(0xFF2ECC71) : const Color(0xFFF5A623),
        ),
      ),
    );
  }
}

class CitySnackHost extends StatelessWidget {
  const CitySnackHost({super.key, required this.message, required this.isError, required this.onDismiss});

  final String? message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Positioned(
      left: 16,
      right: 16,
      top: 12,
      child: Material(
        color: isError ? const Color(0xFF3B1515) : const Color(0xFF153B24),
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          title: Text(message!, style: const TextStyle(fontSize: 13)),
          trailing: IconButton(onPressed: onDismiss, icon: const Icon(Icons.close, size: 18)),
        ),
      ),
    );
  }
}
