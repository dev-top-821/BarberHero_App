import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BarberHeroApp());
}

class BarberHeroApp extends StatelessWidget {
  const BarberHeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BarberHero',
      debugShowCheckedModeBanner: false,
      theme: customerTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        // TODO: Add remaining routes in M2
        // '/login': (context) => const LoginScreen(),
        // '/location': (context) => const LocationScreen(),
        // '/home': (context) => const HomeScreen(),
      },
    );
  }
}
