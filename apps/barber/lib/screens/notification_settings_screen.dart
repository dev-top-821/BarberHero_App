import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Mirrors the customer notification settings screen — surfaces the
/// current FCM permission state, lets the barber re-request, and
/// describes what they'll be notified about. Per-category toggles are a
/// Phase-2 item.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  AuthorizationStatus? _status;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (!mounted) return;
      setState(() {
        _status = settings.authorizationStatus;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  Future<void> _request() async {
    setState(() => _checking = true);
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!mounted) return;
      setState(() {
        _status = settings.authorizationStatus;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final granted = s == AuthorizationStatus.authorized ||
        s == AuthorizationStatus.provisional;

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _checking && s == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (granted ? AppColors.online : AppColors.warning)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          granted
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_rounded,
                          color: granted ? AppColors.online : AppColors.warning,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                granted ? 'Notifications on' : 'Notifications off',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                granted
                                    ? "You'll hear about new bookings, code entries and chat."
                                    : "You won't get booking alerts or chat messages.",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!granted) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _checking ? null : _request,
                        icon: const Icon(Icons.notifications_rounded, size: 18),
                        label: const Text('Allow notifications'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'If the prompt doesn\'t appear, open your device Settings '
                      '→ Apps → BarberHero Pro → Notifications to turn them on.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _Divider("What you'll receive"),
                  const SizedBox(height: 8),
                  const _Row(
                    icon: Icons.event_available_rounded,
                    title: 'New booking requests',
                    subtitle: 'When a customer books you.',
                  ),
                  const _Row(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Customer messages',
                    subtitle: 'New chat from a customer.',
                  ),
                  const _Row(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Wallet updates',
                    subtitle: 'Payment release, withdrawal status, refunds.',
                  ),
                  const _Row(
                    icon: Icons.flag_outlined,
                    title: 'Disputes',
                    subtitle: "If a customer files a report on a booking.",
                  ),
                ],
              ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final String text;
  const _Divider(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Row({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
