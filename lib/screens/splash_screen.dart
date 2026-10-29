import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/preferences_service.dart';
import '../theme/app_colors.dart';
import '../widgets/splash/animated_libris_logo.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PreferencesService _preferencesService = PreferencesService();

  bool _isNavigating = false;

  Future<void> _navigateAfterSplash() async {
    // Védelem arra az esetre, ha az animáció callbackje
    // valamiért egynél többször futna le.
    if (_isNavigating) {
      return;
    }

    _isNavigating = true;

    final bool rememberMe = await _preferencesService.getRememberMe();

    // Ha a felhasználó korábban nem választotta az
    // automatikus bejelentkezést, megszüntetjük a Firebase-sessiont.
    if (!rememberMe && FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }

    if (!mounted) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;

    final Widget destination;

    if (currentUser != null && rememberMe) {
      destination = const MainNavigationScreen();
    } else {
      destination = const LoginScreen();
    }

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return destination;
        },
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );

          return FadeTransition(
            opacity: curvedAnimation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Az animáció szélességét a rendelkezésre álló
            // szélesség és magasság alapján számítjuk ki.
            // Így kisebb telefonokon sem lesz pixel overflow.
            final double logoWidth = math.min(
              constraints.maxWidth * 0.92,
              constraints.maxHeight * 0.82,
            );

            return Center(
              child: SizedBox(
                width: logoWidth.clamp(260.0, 420.0),
                child: AnimatedLibrisLogo(
                  onCompleted: _navigateAfterSplash,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
