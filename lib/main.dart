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
  const MotopassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParSU Motopass',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const LoginScreen(),
    );
  }
}

class MotopassApp extends