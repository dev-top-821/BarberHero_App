import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BarberHeroProApp());
}

class BarberHeroProApp extends StatelessWidget {
  const BarberHeroProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberHero Pro',
      debugShowCheckedModeBanner: false,
      theme: barberTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        // TODO: Add remaining routes in M2-M4
        // '/login': (context) => const LoginScreen(),
        // '/pending': (context) => const PendingScreen(),
        // '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
