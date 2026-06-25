import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'constants/colors.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // App Check settings for development testing
    // Set to true if App Check enforcement is active in your Firebase Console
    bool enableAppCheckInDebug = true;

    // Persistent debug token registered in Firebase Console under App Check > Manage debug tokens
    const String webDebugToken = 'b1761c25-c825-49a0-9932-fed7f28437ad';

    if (!kDebugMode || enableAppCheckInDebug) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: kDebugMode
            ? WebDebugProvider(debugToken: webDebugToken)
            : ReCaptchaV3Provider('6LeBqystAAAAAJS3i4iO7I6aKG8uh-Dt4NgpET8J'),
        providerAndroid: kDebugMode
            ? AndroidDebugProvider(debugToken: webDebugToken)
            : AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? AppleDebugProvider()
            : AppleAppAttestProvider(),
      );
      debugPrint(
        'Firebase App Check activated successfully (enableAppCheckInDebug: $enableAppCheckInDebug).',
      );
    // ignore: dead_code
    } else {
      debugPrint(
        'Firebase App Check is temporarily disabled in development/debug mode.',
      );
    }
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint('Firebase already initialized: $e');
    } else {
      debugPrint('Error initializing Firebase / App Check: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CARRENT System',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.backgroundWhite,
        colorScheme: ColorScheme.light(
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
      home: const HomeScreen(),
    );
  }
}
