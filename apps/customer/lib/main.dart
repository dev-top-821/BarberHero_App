import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:api_client/api_client.dart';
import 'config/theme.dart';
import 'config/env.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/barber_provider.dart';
import 'providers/barber_profile_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/bookings_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/location_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/search_screen.dart';
import 'screens/barber_profile_screen.dart';
import 'screens/booking/booking_screen.dart';
import 'screens/booking/payment_screen.dart';
import 'screens/booking/confirmation_screen.dart';
import 'screens/review/review_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e, st) {
    debugPrint('Firebase init failed: $e\n$st');
  }

  // Set the Stripe key synchronously. Also await applySettings() — the
  // platform SDK needs it done before initPaymentSheet() is called later.
  if (Env.hasStripeKey) {
    Stripe.publishableKey = Env.stripePublishableKey;
    try {
      await Stripe.instance.applySettings();
    } catch (e, st) {
      debugPrint('Stripe applySettings failed: $e\n$st');
    }
  } else {
    debugPrint('WARNING: STRIPE_PUBLISHABLE_KEY is empty — payments will fail.');
  }

  final apiClient = ApiClient(config: ApiConfig.fromUrl(Env.apiBaseUrl));
  final chatRealtime = ChatRealtimeService(apiClient);

  runApp(BarberHeroApp(apiClient: apiClient, chatRealtime: chatRealtime));
}

class BarberHeroApp extends StatelessWidget {
  final ApiClient apiClient;
  final ChatRealtimeService chatRealtime;

  const BarberHeroApp({
    super.key,
    required this.apiClient,
    required this.chatRealtime,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: apiClient),
        Provider.value(value: chatRealtime),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiClient)),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => BarberProvider(apiClient)),
        ChangeNotifierProvider(create: (_) => BarberProfileProvider(apiClient)),
        ChangeNotifierProvider(create: (_) => BookingProvider(apiClient)),
        ChangeNotifierProvider(create: (_) => BookingsProvider(apiClient)),
      ],
      child: MaterialApp(
        title: 'BarberHero',
        debugShowCheckedModeBanner: false,
        navigatorKey: NotificationService.navigatorKey,
        theme: customerTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/location': (context) => const LocationScreen(),
          '/home': (context) {
            // Optionally accept an int via Navigator.pushNamed arguments to
            // open a specific bottom-nav tab (e.g. 1 = Bookings).
            final args = ModalRoute.of(context)?.settings.arguments;
            return HomeShell(initialIndex: args is int ? args : 0);
          },
          '/search': (context) => const SearchScreen(),
          '/booking': (context) => const BookingScreen(),
          '/payment': (context) => const PaymentScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/barber') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => BarberProfileScreen(
                barberId: args['barberId'] as String,
                barberName: args['barberName'] as String?,
                distanceKm: args['distanceKm'] as double?,
              ),
            );
          }
          if (settings.name == '/confirmation') {
            final bookingData = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ConfirmationScreen(bookingData: bookingData),
            );
          }
          if (settings.name == '/review') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => ReviewScreen(
                bookingId: args['bookingId'] as String,
                barberName: args['barberName'] as String,
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}
