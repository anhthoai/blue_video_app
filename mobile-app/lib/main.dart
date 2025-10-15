import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/storage_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/nsfw_settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase (disabled for testing with mock data)
  // await Firebase.initializeApp();

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize services
  await StorageService.init();
  // await NotificationService.init(); // Disabled for testing (requires Firebase)

  // Initialize AuthService
  final prefs = await SharedPreferences.getInstance();
  final authService = AuthService(prefs);
  final nsfwSettingsService = NsfwSettingsService(prefs);

  // Reload current user with fresh data from API
  await authService.reloadCurrentUser();

  runApp(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
      nsfwSettingsServiceProvider.overrideWithValue(nsfwSettingsService),
    ],
    child: const BlueVideoApp(),
  ));
}

class BlueVideoApp extends ConsumerWidget {
  const BlueVideoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // App is ready to use real API

    return MaterialApp.router(
      title: 'Blue Video App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: const [
        // Add localization delegates here
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
    );
  }
}
