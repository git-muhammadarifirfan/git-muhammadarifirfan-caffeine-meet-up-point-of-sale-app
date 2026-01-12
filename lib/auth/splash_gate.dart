import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/onboarding_page.dart';
import '../auth/login_page.dart';
import '../pages/home_page.dart';
import '../services/auth_service.dart';
import '../core/notifier.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  static const Duration _minSplash = Duration(milliseconds: 1500);
  bool _fadeOut = false;

  // Background gradient (biru-ungu)
  static const _primary = Color(0xFF4A8DFF);
  static const _secondary = Color(0xFF5B46FF);

  // Paths logo
  static const String _logoMager = 'assets/logo/mager_logo_load.png';
  static const String _logoCaffeine = 'assets/logo/caffeine_meetup.png';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _boot();
    });
  }

  Future<void> _boot() async {
    final startedAt = DateTime.now();
    Widget target = const LoginPage();

    try {
      final prefs = await SharedPreferences.getInstance();
      final seenOnboard = prefs.getBool('seen_onboarding') ?? false;
      final user = Supabase.instance.client.auth.currentUser;

      if (!seenOnboard) {
        target = const OnboardingPage();
      } else {
        if (user != null) {
          try {
            await AuthService.loadProfile().timeout(const Duration(seconds: 3));
            target = const HomePage();
          } catch (_) {
            if (mounted) {
              notify(
                context,
                'Failed to load profile, try logging in again.',
                error: true,
              );
            }
            target = const LoginPage();
          }
        } else {
          target = const LoginPage();
        }
      }
    } catch (_) {
      target = const LoginPage();
    }

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _minSplash - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;
    setState(() => _fadeOut = true);
    await Future.delayed(const Duration(milliseconds: 220));

    if (!mounted) return;
    _go(target);
  }

  void _go(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, __, child) {
          final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  Widget _whiteLogo(String asset, double size) {
    return Image.asset(
      asset,
      height: size,
      width: size,
      fit: BoxFit.contain,
      // bikin putih (cocok untuk logo hitam/warna gelap)
      color: Colors.white,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, __, ___) => SizedBox(
        height: size,
        width: size,
        child: Icon(Icons.image_not_supported_outlined,
            color: Colors.white.withOpacity(0.85)),
      ),
    );
  }

  Widget _xMark(double fontSize) {
    return Container(
      height: fontSize * 1.55,
      width: fontSize * 1.55,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.14),
        border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
      ),
      child: Text(
        '×',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final shortest = mq.size.shortestSide;
    final isTablet = shortest >= 600;

    final double logoSize = isTablet ? 120 : 92; // simple + pas
    final double xSize = isTablet ? 22 : 20;

    return Scaffold(
      body: SafeArea(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          opacity: _fadeOut ? 0 : 1,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primary, _secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // soft glow background (halus)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // glow besar
                        Container(
                          height: isTablet ? 320 : 260,
                          width: isTablet ? 320 : 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.10),
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 350.ms)
                            .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 650.ms, curve: Curves.easeOutBack),

                        // glow kecil kanan atas
                        Positioned(
                          top: isTablet ? 10 : 6,
                          right: isTablet ? 18 : 12,
                          child: Container(
                            height: isTablet ? 120 : 96,
                            width: isTablet ? 120 : 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.07),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 520.ms)
                              .then()
                              .moveY(begin: 0, end: -8, duration: 1500.ms, curve: Curves.easeInOut)
                              .then()
                              .moveY(begin: -8, end: 0, duration: 1500.ms, curve: Curves.easeInOut),
                        ),

                        // LOGO x LOGO (tanpa kotak)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _whiteLogo(_logoMager, logoSize)
                                .animate()
                                .fadeIn(duration: 420.ms)
                                .slideY(begin: 0.06, end: 0, duration: 520.ms, curve: Curves.easeOutBack),
                            const SizedBox(width: 14),
                            _xMark(xSize)
                                .animate()
                                .fadeIn(duration: 520.ms)
                                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 520.ms, curve: Curves.easeOutBack),
                            const SizedBox(width: 14),
                            _whiteLogo(_logoCaffeine, logoSize)
                                .animate()
                                .fadeIn(duration: 520.ms)
                                .slideY(begin: 0.06, end: 0, duration: 600.ms, curve: Curves.easeOutBack),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    Text(
                      'Mager Coffee Lab × Caffeine Meet Up',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 520.ms, delay: 120.ms)
                        .slideY(begin: 0.10, end: 0, duration: 520.ms, curve: Curves.easeOut),

                    const SizedBox(height: 8),

                    Text(
                      'Point of Sale',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.90),
                        fontSize: isTablet ? 14 : 13,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 0.6,
                      ),
                    ).animate().fadeIn(duration: 520.ms, delay: 200.ms),

                    const SizedBox(height: 22),

                    const SizedBox(
                      height: 26,
                      width: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: Colors.white,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .rotate(begin: -0.03, end: 0.03, duration: 850.ms, curve: Curves.easeInOut)
                        .then()
                        .rotate(begin: 0.03, end: -0.03, duration: 850.ms, curve: Curves.easeInOut),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
