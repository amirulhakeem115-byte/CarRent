import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'constants/colors.dart';
import 'screens/home_screen.dart';
import 'services/company_settings_provider.dart';
import 'services/theme_provider.dart';
import 'ai/services/ai_service.dart';
import 'services/user_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    await FirebaseAppCheck.instance.activate(
      providerWeb: kDebugMode
          ? WebDebugProvider(debugToken: 'b1761c25-c825-49a0-9932-fed7f28437ad')
          : ReCaptchaV3Provider('6LeBqystAAAAAJS3i4iO7I6aKG8uh-Dt4NgpET8J'),
      providerAndroid: kDebugMode
          ? AndroidDebugProvider()
          : AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? AppleDebugProvider()
          : AppleAppAttestProvider(),
    );

    // Initialize user session monitoring
    UserSession().initialize();
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint('Firebase already initialized: $e');
    } else {
      debugPrint('Error initializing Firebase / App Check: $e');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CompanySettingsProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AIService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final companyName = context.watch<CompanySettingsProvider>().companyName;
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '$companyName System',
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.backgroundWhite,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primaryOrange,
          secondary: AppColors.secondaryBlue,
          surface: AppColors.backgroundWhite,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.secondaryBlue,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightGray,
          labelStyle: const TextStyle(color: AppColors.lightText),
          floatingLabelStyle: const TextStyle(color: AppColors.primaryOrange),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderGray),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderGray),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primaryOrange,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        dividerColor: const Color(0xFF334155),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryOrange,
          surface: Color(0xFF111827),
          onSurface: Color(0xFFF8FAFC),
          onSurfaceVariant: Color(0xFFCBD5E1),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF8FAFC)),
          bodyMedium: TextStyle(color: Color(0xFFCBD5E1)),
          bodySmall: TextStyle(color: Color(0xFF94A3B8)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Color(0xFFF8FAFC),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
          floatingLabelStyle: const TextStyle(color: AppColors.primaryOrange),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primaryOrange,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
