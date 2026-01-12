import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/notifier.dart';
import '../core/supabase.dart';
import '../services/auth_service.dart';
import '../pages/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;
  bool obscure = true;

  static const _primary = Color(0xFF2F6BFF);
  static const _bg = Color(0xFFF6FAFF);

  // text
  static const _text = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  // field
  static const _stroke = Color(0xFFE8EEF7);
  static const _fieldFill = Color(0xFFF6F8FC);

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (email.text.isEmpty || pass.text.isEmpty) {
      notify(context, 'Email & password wajib diisi', error: true);
      return;
    }

    setState(() => loading = true);

    try {
      await Supa.client.auth.signInWithPassword(
        email: email.text.trim(),
        password: pass.text.trim(),
      );

      // 🔥 WAJIB LOAD PROFILE
      await AuthService.loadProfile();

      if (!mounted) return;
      notify(context, 'Login berhasil');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } catch (e) {
      if (!mounted) return;
      notify(context, 'Email atau password salah', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  InputDecoration _dec({
    required String label,
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: _fieldFill,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primary, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final shortest = size.shortestSide;
    final isTablet = shortest >= 600;

    final maxW = isTablet ? 600.0 : 520.0;
    final pad = isTablet ? 24.0 : 18.0;

    // tinggi hero mengikuti layar biar tetep cakep di hp kecil / tablet
    final heroH = (size.height * (isTablet ? 0.52 : 0.46))
        .clamp(isTablet ? 360.0 : 300.0, isTablet ? 520.0 : 420.0)
        .toDouble();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            // ======= BACKGROUND: gradient + dots + wave anim (3 layer) =======
            Positioned.fill(
              child: _FixedLoginBackground(heroHeight: heroH),
            ),

            // ======= CONTENT =======
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, 14, pad, pad),
                  child: Column(
                    children: [
                      // ======= BRAND HEADER =======
                      SizedBox(height: isTablet ? 20 : 12),
                      _BrandHeader(isTablet: isTablet)
                          .animate()
                          .fadeIn(duration: 260.ms)
                          .slideY(begin: -0.12, end: 0, duration: 360.ms, curve: Curves.easeOut),

                      SizedBox(height: isTablet ? 18 : 14),

                      // ======= CARD LOGIN =======
                      Container(
                        padding: EdgeInsets.all(isTablet ? 22 : 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.94),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: _stroke),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 30,
                              offset: Offset(0, 14),
                              color: Color(0x16000000),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
  children: [
    _IconBadge(isTablet: isTablet), // ✅ NO ANIMATION
    const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Log in',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _text,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Masuk untuk melanjutkan ke POS.',
            style: TextStyle(
              fontSize: 12.8,
              fontWeight: FontWeight.w700,
              color: _muted,
            ),
          ),
        ],
      ),
    ),
  ],
),
                            const SizedBox(height: 18),

                            // Email
                            TextField(
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _dec(
                                label: 'Email',
                                hint: 'your@email.com',
                                prefix: const Icon(Icons.alternate_email_rounded, color: _muted),
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 80.ms, duration: 260.ms)
                                .slideY(begin: 0.10, end: 0, duration: 300.ms, curve: Curves.easeOut),

                            const SizedBox(height: 12),

                            // Password
                            TextField(
                              controller: pass,
                              obscureText: obscure,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => loading ? null : login(),
                              decoration: _dec(
                                label: 'Password',
                                hint: '••••••••',
                                prefix: const Icon(Icons.lock_rounded, color: _muted),
                                suffix: IconButton(
                                  onPressed: () => setState(() => obscure = !obscure),
                                  icon: Icon(
                                    obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                    color: _muted,
                                  ),
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 120.ms, duration: 260.ms)
                                .slideY(begin: 0.10, end: 0, duration: 300.ms, curve: Curves.easeOut),

                            const SizedBox(height: 16),

                            // Button
                            SizedBox(
                              height: 54,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  elevation: 0,
                                ),
                                onPressed: loading ? null : login,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: loading
                                      ? const SizedBox(
                                          key: ValueKey('loading'),
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          key: const ValueKey('text'),
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.login_rounded, color: Colors.white, size: 18),
                                            SizedBox(width: 10),
                                            Text(
                                              'Connect',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 160.ms, duration: 260.ms)
                                .slideY(begin: 0.10, end: 0, duration: 300.ms, curve: Curves.easeOut),

                            const SizedBox(height: 14),
                            Container(height: 1, color: _stroke),
                            const SizedBox(height: 12),

                            const Text(
                              'Tip: Pakai akun kasir yang sudah dibuat di sistem.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.6,
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 220.ms, duration: 260.ms)
                                .slideY(begin: 0.06, end: 0, duration: 260.ms, curve: Curves.easeOut),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 80.ms, duration: 260.ms)
                          .slideY(begin: 0.14, end: 0, duration: 360.ms, curve: Curves.easeOut)
                          .scale(begin: const Offset(0.985, 0.985), end: const Offset(1, 1), duration: 360.ms),

                      SizedBox(height: isTablet ? 18 : 14),

                      Opacity(
                        opacity: 0.92,
                        child: Text(
                          'Mager Coffee x Caffeine Meet up • Secure Sign-in',
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w800,
                            fontSize: isTablet ? 12.6 : 12.0,
                          ),
                        ),
                      ).animate().fadeIn(delay: 260.ms, duration: 260.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.isTablet});
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: isTablet ? 88 : 80,
          height: isTablet ? 88 : 80,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Image.asset(
            'assets/logo/mager_logo.png',
            fit: BoxFit.contain,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .moveY(begin: 0, end: -8, duration: 900.ms, curve: Curves.easeInOut)
            .then()
            .moveY(begin: -8, end: 0, duration: 900.ms, curve: Curves.easeInOut),
        const SizedBox(height: 12),
        Text(
          'Mager Coffee x Caffeine Meet up',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isTablet ? 22 : 20,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Login biar bisa mulai transaksi.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isTablet ? 13.2 : 12.6,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.88),
          ),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.isTablet});
  final bool isTablet;

  static const _primary = Color(0xFF2F6BFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isTablet ? 56 : 52,
      width: isTablet ? 56 : 52,
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x26000000),
          ),
        ],
      ),
      child: Icon(Icons.local_cafe_rounded, color: Colors.white, size: isTablet ? 28 : 26),
    );
  }
}

/// Background fixed + dots anim + 3 layer wave anim (mirip onboarding)
class _FixedLoginBackground extends StatefulWidget {
  const _FixedLoginBackground({required this.heroHeight});
  final double heroHeight;

  @override
  State<_FixedLoginBackground> createState() => _FixedLoginBackgroundState();
}

class _FixedLoginBackgroundState extends State<_FixedLoginBackground> with TickerProviderStateMixin {
  late final AnimationController _dotsC;
  late final AnimationController _waveC;

  @override
  void initState() {
    super.initState();
    _dotsC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _waveC = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  }

  @override
  void dispose() {
    _dotsC.dispose();
    _waveC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // top gradient hero
        SizedBox(
          height: widget.heroHeight,
          width: double.infinity,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5A3FE0),
                  Color(0xFF2F6BFF),
                  Color(0xFF7AA6FF),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        // dots anim
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: widget.heroHeight,
          child: AnimatedBuilder(
            animation: _dotsC,
            builder: (_, __) => CustomPaint(painter: _SideDotsPainter(t: _dotsC.value)),
          ),
        ),

        // wave anim (3 layer) - nyambung ke background putih
        Positioned(
          left: 0,
          right: 0,
          top: widget.heroHeight - 170,
          height: 220,
          child: AnimatedBuilder(
            animation: _waveC,
            builder: (_, __) {
              final t = _waveC.value;
              return Stack(
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: _AnimatedWavePainter(
                      color: const Color(0xFFEAF2FF).withOpacity(0.55),
                      t: t,
                      amp: 14,
                      base: 82,
                      phase: 0.0,
                    ),
                  ),
                  CustomPaint(
                    size: Size.infinite,
                    painter: _AnimatedWavePainter(
                      color: const Color(0xFFEAF2FF).withOpacity(0.78),
                      t: t,
                      amp: 18,
                      base: 92,
                      phase: 1.2,
                    ),
                  ),
                  CustomPaint(
                    size: Size.infinite,
                    painter: _AnimatedWavePainter(
                      color: const Color(0xFFF6FAFF),
                      t: t,
                      amp: 24,
                      base: 104,
                      phase: 2.0,
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // fill bottom background
        Positioned.fill(
          top: widget.heroHeight - 20,
          child: Container(color: const Color(0xFFF6FAFF)),
        ),
      ],
    );
  }
}

/// dots painter fokus sisi kiri/kanan atas
class _SideDotsPainter extends CustomPainter {
  _SideDotsPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    void dot(double x, double y, double r, double op) {
      paint.color = Colors.white.withOpacity(op);
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    final a = t * 2 * math.pi;

    // kiri
    dot(size.width * 0.10 + math.sin(a) * 8, size.height * 0.18 + math.cos(a) * 10, 12, 0.16);
    dot(size.width * 0.16 + math.cos(a * 1.1) * 10, size.height * 0.30 + math.sin(a * 0.9) * 8, 16, 0.10);
    dot(size.width * 0.22 + math.sin(a * 0.8) * 10, size.height * 0.10 + math.cos(a * 1.2) * 8, 10, 0.14);

    // kanan
    dot(size.width * 0.86 + math.cos(a * 1.0) * 10, size.height * 0.16 + math.sin(a * 1.1) * 10, 14, 0.14);
    dot(size.width * 0.80 + math.sin(a * 0.9) * 10, size.height * 0.28 + math.cos(a * 1.05) * 8, 18, 0.10);
    dot(size.width * 0.92 + math.sin(a * 0.7) * 8, size.height * 0.24 + math.cos(a * 0.9) * 10, 10, 0.12);
  }

  @override
  bool shouldRepaint(covariant _SideDotsPainter oldDelegate) => oldDelegate.t != t;
}

class _AnimatedWavePainter extends CustomPainter {
  _AnimatedWavePainter({
    required this.color,
    required this.t,
    required this.amp,
    required this.base,
    required this.phase,
  });

  final Color color;
  final double t;
  final double amp;
  final double base;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final path = Path();
    final y0 = base;
    final shift = (t * size.width);

    path.moveTo(0, y0);

    const step = 18.0;
    for (double x = 0; x <= size.width + step; x += step) {
      final xx = x + shift;
      final v = math.sin((xx / size.width) * math.pi * 2 + phase);
      final y = y0 + v * amp;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedWavePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}
