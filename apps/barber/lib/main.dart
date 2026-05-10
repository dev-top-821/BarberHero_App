import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:api_client/api_client.dart';
import 'config/theme.dart';
import 'config/env.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/auth/rejected_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home/home_shell.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final apiClient = ApiClient(config: ApiConfig.fromUrl(Env.apiBaseUrl));
  final chatRealtime = ChatRealtimeService(apiClient);

  runApp(BarberHeroProApp(apiClient: apiClient, chatRealtime: chatRealtime));
}

class BarberHeroProApp extends StatelessWidget {
  final ApiClient apiClient;
  final ChatRealtimeService chatRealtime;

  const BarberHeroProApp({
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
      ],
      child: MaterialApp(
        title: 'BarberHero Pro',
        debugShowCheckedModeBanner: false,
        navigatorKey: NotificationService.navigatorKey,
        theme: barberTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/pending': (context) => const PendingApprovalScreen(),
          '/rejected': (context) => const RejectedScreen(),
          '/dashboard': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            return HomeShell(initialIndex: args is int ? args : 0);
          },
        },
      ),
    );
  }
}
