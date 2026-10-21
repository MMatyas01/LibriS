import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../Services/preferences_service.dart';

import '../theme/app_colors.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _bookScale;
  late final Animation<double> _leftPageOpening;
  late final Animation<double> _rightPageOpening;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _accentWidth;
  final _preferencesService = PreferencesService();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    // A teljes könyv finom megjelenése és nagyítása.
    _bookScale = Tween<double>(
      begin: 0.72,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0,
          0.48,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    // A bal könyvoldal kinyílása.
    _leftPageOpening = Tween<double>(
      begin: 0.12,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.12,
          0.65,
          curve: Curves.easeInOutCubic,
        ),
      ),
    );

    // A jobb könyvoldal kinyílása.
    _rightPageOpening = Tween<double>(
      begin: 0.12,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.18,
          0.70,
          curve: Curves.easeInOutCubic,
        ),
      ),
    );

    // A LibriS név és a mottó megjelenése.
    _contentOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.63,
          0.92,
          curve: Curves.easeIn,
        ),
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.63,
          0.94,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    // A márkajelzésként használt rövid zöld vonal animációja.
    _accentWidth = Tween<double>(
      begin: 0,
      end: 48,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.73,
          1,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    await _controller.forward();

    // A teljesen kinyílt könyv még rövid ideig látható marad.
    await Future<void>.delayed(
      const Duration(milliseconds: 900),
    );

    if (!mounted) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final rememberMe = await _preferencesService.getRememberMe();

    if (!rememberMe && user != null) {
      await FirebaseAuth.instance.signOut();
    }

    if (!mounted) {
      return;
    }

    final Widget destination =
        rememberMe && FirebaseAuth.instance.currentUser != null
            ? const MainNavigationScreen()
            : const LoginScreen();

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(
          milliseconds: 550,
        ),
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
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _bookScale.value,
                  child: _buildAnimatedBook(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBook() {
    return SizedBox(
      width: 340,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Finom árnyék a könyv alatt.
          Positioned(
            left: 42,
            right: 42,
            bottom: 20,
            child: Opacity(
              opacity: _controller.value.clamp(0, 0.18),
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.charcoal.withValues(
                        alpha: 0.12,
                      ),
                      blurRadius: 24,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // A Forest színű külső könyvborító.
          Positioned(
            top: 38,
            bottom: 40,
            left: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.charcoal.withValues(
                      alpha: 0.16,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
            ),
          ),

          // Bal oldal.
          Positioned(
            top: 28,
            bottom: 48,
            left: 14,
            right: 170,
            child: Transform.scale(
              alignment: Alignment.centerRight,
              scaleX: _leftPageOpening.value,
              child: _buildLeftPage(),
            ),
          ),

          // Jobb oldal.
          Positioned(
            top: 28,
            bottom: 48,
            left: 170,
            right: 14,
            child: Transform.scale(
              alignment: Alignment.centerLeft,
              scaleX: _rightPageOpening.value,
              child: _buildRightPage(),
            ),
          ),

          // A könyv gerincénél megjelenő finom árnyék.
          Positioned(
            top: 35,
            bottom: 55,
            child: Opacity(
              opacity: _contentOpacity.value,
              child: Container(
                width: 12,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors.charcoal.withValues(
                        alpha: 0.15,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPage() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(15),
        bottomLeft: Radius.circular(15),
        topRight: Radius.circular(4),
        bottomRight: Radius.circular(4),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              AppColors.sage,
              AppColors.ivory,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Oldal szélén lévő Forest dekoráció.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 7,
                color: AppColors.forest,
              ),
            ),

            // Terrakotta könyvjelző.
            Positioned(
              top: 0,
              right: 22,
              child: ClipPath(
                clipper: BookmarkClipper(),
                child: Container(
                  width: 24,
                  height: 58,
                  color: AppColors.terracotta,
                ),
              ),
            ),

            Center(
              child: FadeTransition(
                opacity: _contentOpacity,
                child: const Icon(
                  Icons.auto_stories_outlined,
                  size: 56,
                  color: AppColors.forest,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightPage() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        bottomLeft: Radius.circular(4),
        topRight: Radius.circular(15),
        bottomRight: Radius.circular(15),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppColors.sage,
              AppColors.ivory,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _contentOpacity,
          child: SlideTransition(
            position: _contentSlide,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'LibriS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.charcoal,
                    fontFamily: 'Georgia',
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _accentWidth,
                  builder: (context, child) {
                    return Container(
                      width: _accentWidth.value,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.forest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'A little time\nfor a good book.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A Terracotta könyvjelző alján lévő V alakú kivágás.
class BookmarkClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 10)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(
    covariant CustomClipper<Path> oldClipper,
  ) {
    return false;
  }
}
