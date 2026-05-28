import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../services/app_mode.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _goLocationOrHome() async {
    final location = context.read<LocationProvider>();
    final hasLocation = await location.loadSavedLocation();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, hasLocation ? '/home' : '/location');
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final mode = await AppModeService.load();
    if (!mounted) return;

    switch (mode) {
      case AppMode.firstRun:
        // Brand-new device — offer all three entry points.
        Navigator.pushReplacementNamed(context, '/welcome');
        return;

      case AppMode.guest:
        // Guest once, guest on every cold start — straight into the app.
        // Booking wall will trigger on /payment for unauthenticated users.
        await _goLocationOrHome();
        return;

      case AppMode.account:
        // Device has been through an account at some point. Try the token;
        // fall back to login (never Welcome — guest is revoked).
        final auth = context.read<AuthProvider>();
        final isLoggedIn = await auth.checkAuth();
        if (!mounted) return;
        if (isLoggedIn) {
          await _goLocationOrHome();
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 100,
            ),
            const SizedBox(height: 16),
            const Text(
              'BARBERHERO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
