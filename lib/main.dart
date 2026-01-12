import 'package:flutter/material.dart';
import 'core/supabase.dart';
import 'core/pos_theme.dart';
import 'auth/splash_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supa.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: PosTheme.light(),
      home: const SplashGate(),
    );
  }
}
