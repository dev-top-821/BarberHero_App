import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/app_mode.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _continueAsGuest(BuildContext context) async {
    await AppModeService.setGuest();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/location');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo + title
              Image.asset('assets/images/logo.png', height: 96),
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
              const SizedBox(height: 12),
              const Text(
                'Find and book mobile barbers near you.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 4),

              // Sign Up
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text('Sign Up'),
                ),
              ),
              const SizedBox(height: 12),

              // Log In
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Log In'),
                ),
              ),
              const SizedBox(height: 20),

              // Continue as guest
              TextButton(
                onPressed: () => _continueAsGuest(context),
                child: const Text(
                  'Continue as guest',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white70,
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
