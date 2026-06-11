import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';

import 'firebase_options.dart';

// NOTE: STEP 28 (FCM) will require pub deps (firebase_messaging + flutter_local_notifications).
// Those deps currently are not installed in this repo due to dependency conflicts.
// import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (tolerant for web/dev)
  await dotenv.load(fileName: '.env').catchError((_) {});

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
