import 'package:flutter/material.dart';

class AppBreakpoints {
  const AppBreakpoints._();

  static const double compactShell = 900;
  static const double wideShell = 1100;
  static const double splitPane = 920;
}

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  static const EdgeInsets page = EdgeInsets.all(lg);
  static const EdgeInsets section = EdgeInsets.fromLTRB(lg, md, lg, sm);
  static const EdgeInsets card = EdgeInsets.all(14);
  static const EdgeInsets dialogContent = EdgeInsets.all(lg);
}

class AppRadius {
  const AppRadius._();

  static const double sm = 6;
  static const double md = 8;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
}

class AppTheme {
  const AppTheme._();

  static const Color seedColor = Color(0xFF146C5C);
  static const Color scaffoldColor = Color(0xFFF7F8F5);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldColor,
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: AppRadius.card),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 68),
      listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.all(0)),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
    );
  }
}

extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
}
