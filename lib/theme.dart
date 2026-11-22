import 'package:flutter/material.dart';

/// Colors taken from the low-fidelity Figma layout.
class AppColors {
  static const header = Color(0xFF6E6E6E);
  static const darkCard = Color(0xFF575757);
  static const green = Color(0xFF8FA36B);
  static const greenDark = Color(0xFF5E7A3A);
  static const greenLight = Color(0xFFE6EDDA);
  static const lightCard = Color(0xFFEDEDED);
  static const border = Color(0xFFD0D0D0);
  static const text = Color(0xFF1E1E1E);
  static const muted = Color(0xFF6B6B6B);
  static const inactive = Color(0xFFCFCFCF);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: 8),
      hintStyle: TextStyle(color: AppColors.muted),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.muted),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.greenDark, width: 2),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.green : null,
      ),
    ),
  );
}
