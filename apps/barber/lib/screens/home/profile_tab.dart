import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../availability_screen.dart';
import '../notification_settings_screen.dart';
import '../onboarding_screen.dart';
import '../reviews_screen.dart';

/// Profile tab in the barber bottom nav. Surfaces the secondary actions
/// that previously lived behind the dashboard's overflow menu — edit
/// profile, working hours, reviews, log out — in a single scrollable list.
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          if (user != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.surface,
                    backgroundImage: user.profilePhoto != null
                        ? CachedNetworkImageProvider(user.profilePhoto!)
                        : null,
                    child: user.profilePhoto == null
                        ? Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
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
            const SizedBox(height: 24),
          ],
          _Tile(
            icon: Icons.person_outline_rounded,
            label: 'Edit profile',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            ),
          ),
          _Tile(
            icon: Icons.schedule_rounded,
            label: 'Working hours',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AvailabilityScreen()),
            ),
          ),
          _Tile(
            icon: Icons.star_outline_rounded,
            label: 'My reviews',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReviewsScreen()),
            ),
          ),
          _Tile(
            icon: Icons.notifications_outlined,
            label: 'Notification settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
          const Divider(height: 32, color: AppColors.border),
          _Tile(
            icon: Icons.description_outlined,
            label: 'Terms of Service',
            onTap: () => _openUrl(context, _termsUrl),
          ),
          _Tile(
            icon: Icons.privacy_tip_outlined,
            label: 'Privacy Policy',
            onTap: () => _openUrl(context, _privacyUrl),
          ),
          const Divider(height: 32, color: AppColors.border),
          _Tile(
            icon: Icons.logout_rounded,
            label: 'Log out',
            destructive: true,
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }

  static const _termsUrl = 'https://barberhero.app/legal/barber-terms';
  static const _privacyUrl = 'https://barberhero.app/legal/privacy';

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          color: color,
          fontWeight: destructive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing: destructive
          ? null
          : const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
