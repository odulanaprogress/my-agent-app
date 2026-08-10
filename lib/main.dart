import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'app/app.dart';

import 'firebase_options.dart';

import 'package:onesignal_flutter/onesignal_flutter.dart';

// NOTE: STEP 28 (FCM) will require pub deps (firebase_messaging + flutter_local_notifications).
// Those deps currently are not installed in this repo due to dependency conflicts.
// import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (tolerant for web/dev)
  await dotenv.load(fileName: '.env').catchError((_) {});

  // Initialize OneSignal (Mobile platforms only)
  if (!kIsWeb) {
    final oneSignalAppId = dotenv.env['ONESIGNAL_APP_ID'];
    if (oneSignalAppId != null && oneSignalAppId.isNotEmpty) {
      try {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
        OneSignal.initialize(oneSignalAppId);
        OneSignal.Notifications.requestPermission(true);
      } catch (e) {
        debugPrint('OneSignal initialization error: $e');
      }
    }
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase App Check for Bot Protection
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
      webProvider: ReCaptchaV3Provider('YOUR_RECAPTCHA_SITE_KEY'),
    );
  } catch (e) {
    debugPrint('Firebase App Check skipped: $e');
  }

  // Use the router-based app so onboarding/privacy/auth routing is active.
  runApp(ProviderScope(child: const AgentApp()));
}

class SplashApp extends StatelessWidget {
  const SplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AGENT',
      theme: ThemeData.light(useMaterial3: false),
      home: const SizedBox.shrink(),
    );
  }
}
