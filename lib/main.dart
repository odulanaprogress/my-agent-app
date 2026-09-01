import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'app/app.dart';
import 'firebase_options.dart';

import 'package:onesignal_flutter/onesignal_flutter.dart';

// Public IDs — safe to embed in the client binary.
// These are NOT secrets; they identify the app, not authenticate it.
const _kOneSignalAppId = String.fromEnvironment(
  'ONESIGNAL_APP_ID',
  defaultValue: '6b319216-e8b1-4cc4-826a-ec7c482ff9c4',
);


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize OneSignal (Mobile platforms only)
  if (!kIsWeb && _kOneSignalAppId.isNotEmpty) {
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      OneSignal.initialize(_kOneSignalAppId);
      OneSignal.Notifications.requestPermission(true);
    } catch (e) {
      debugPrint('OneSignal initialization error: $e');
    }
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.NONE);
  }



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
