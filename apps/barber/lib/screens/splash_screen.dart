import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';

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

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final isLoggedIn = await auth.checkAuth();

    if (!mounted) return;

    if (!isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // Route by barber onboarding/approval status. `barberStatus` comes
    // from /users/me on checkAuth — BLOCKED falls through to /pending
    // so we don't tip the user off mid-moderation.
    switch (auth.barberStatus) {
      case 'INCOMPLETE':
        Navigator.pushReplacementNamed(context, '/onboarding');
        return;
      case 'PENDING':
        Navigator.pushReplacementNamed(context, '/pending');
        return;
      case 'REJECTED':
        Navigator.pushReplacementNamed(context, '/rejected');
        return;
      case 'APPROVED':
        Navigator.pushReplacementNamed(context, '/dashboard');
        return;
      default:
        // BLOCKED or unknown — keep them on the pending screen so any
        // support communication is unified.
        Navigator.pushReplacementNamed(context, '/pending');
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
              'BARBERHERO PRO',
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
