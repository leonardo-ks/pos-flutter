import 'package:flutter/material.dart';

import '../auth/screens/login_screen.dart';
import '../core/theme/app_theme.dart';
import 'app_controller.dart';
import 'app_scope.dart';
import 'home_shell.dart';

class PosKasirApp extends StatefulWidget {
  const PosKasirApp({super.key, this.controller});

  final AppController? controller;

  @override
  State<PosKasirApp> createState() => _PosKasirAppState();
}

class _PosKasirAppState extends State<PosKasirApp> {
  late final AppController _controller =
      widget.controller ?? AppController.api();

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: MaterialApp(
        title: 'POS Kasir',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (!_controller.isLoggedIn) return const LoginScreen();
            return const HomeShell();
          },
        ),
      ),
    );
  }
}
