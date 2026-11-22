import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/auth_screens.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const MotopassApp());
}

class MotopassApp extends StatelessWidget {
  const MotopassApp({
    super.key,
    this.demo = kDebugMode && const bool.fromEnvironment('MOTOPASS_DEMO'),
  });
  final bool demo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParSU Motopass',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: LoginScreen(demo: demo),
    );
  }
}
