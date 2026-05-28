import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../edit_profile_screen.dart';
import '../help_screen.dart';
import '../notification_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    // Guest view — no account tied to this device yet.
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: _GuestProfile(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // ─── Header ───
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      if (user.phone != null && user.phone!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.phone!,
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),

          // ─── Settings list ───
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notification Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
            ),
          ),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),

          const Divider(height: 1),

          // ─── Legal — placeholders the client provides on cutover.
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => _openUrl(context, _termsUrl),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _openUrl(context, _privacyUrl),
          ),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // ─── Account ───
          _SettingsTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Account',
            titleColor: AppColors.error,
            iconColor: AppColors.error,
            onTap: () => _confirmDeleteAccount(context),
          ),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Log Out',
            titleColor: AppColors.error,
            iconColor: AppColors.error,
            showArrow: false,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  static const _termsUrl = 'https://barberhero.app/legal/terms';
  static const _privacyUrl = 'https://barberhero.app/legal/privacy';
  static const _supportEmail = 'support@barberhero.app';

  Future<void> _openUrl(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  // GDPR-light placeholder: opens the user's mail client with a deletion
  // request. Full self-service delete is Phase 2 — admin handles it on
  // request today.
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          "We don't have a self-service delete yet. Tap continue to email "
          "support and we'll process your request within 7 days.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Continue',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=Delete my BarberHero account',
    );
    if (!await launchUrl(uri)) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not open mail app — email $_supportEmail directly.'),
      ));
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Log Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _GuestProfile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "You're browsing as a guest",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Create an account to book, save favourites and get booking updates.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('Sign Up'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('Log In'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? titleColor;
  final Color? iconColor;
  final bool showArrow;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.titleColor,
    this.iconColor,
    this.showArrow = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textPrimary, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      trailing: showArrow
          ? const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary)
          : null,
      onTap: onTap,
    );
  }
}
