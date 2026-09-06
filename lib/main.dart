import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'screens/session_gate.dart';
import 'services/push_notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/sos_notification_host.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
    RemoteMessage message,
    ) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dsjxxxffhmyhdfsgtlwm.supabase.co',
    publishableKey: 'sb_publishable_Zgv0AL5QYKetgfEk6Pn-HQ_ea16YY95',
  );

  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    await PushNotificationService.instance.initialize();
  }

  runApp(const SafeZoneApp());
}

class SafeZoneApp extends StatefulWidget {
  const SafeZoneApp({super.key});

  @override
  State<SafeZoneApp> createState() => _SafeZoneAppState();
}

class _SafeZoneAppState extends State<SafeZoneApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      title: 'SafeZone MY',
      theme: AppTheme.darkTheme,
      home: const SessionGate(),
      builder: (context, child) {
        return SosNotificationHost(
          navigatorKey: _navigatorKey,
          messengerKey: _messengerKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}