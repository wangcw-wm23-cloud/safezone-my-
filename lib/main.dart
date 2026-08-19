import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://dsjxxxffhmyhdfsgtlwm.supabase.co',
    publishableKey: 'sb_publishable_Zgv0AL5QYKetgfEk6Pn-HQ_ea16YY95',
  );

  runApp(const SafeZoneApp());
}

class SafeZoneApp extends StatelessWidget {
  const SafeZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeZone MY',
      theme: AppTheme.darkTheme,
      home: const LoginScreen(),
    );
  }
}