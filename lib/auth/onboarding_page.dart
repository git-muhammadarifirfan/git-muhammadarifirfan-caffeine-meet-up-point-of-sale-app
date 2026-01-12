import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pc;
  int _index = 0;

  static const _primary = Color(0xFF2F6BFF);
  static const _bg = Color(0xFFF6FAFF);

  // dark blue (hampir hitam)
  static const _titleText = Color(0xFF0B1B3A);
  static const _bodyText = Color(0xFF243B68);

  final pages = const [
    _OnbData(
      title: 'Kasir cepat & rapi',
      subtitle: 'Cari produk cepat, tap masuk cart.\nCheckout simpel biar antrian nggak numpuk.',
      icon: Icons.point_of_sale_rounded,
    ),
    _OnbData(
      title: 'Order & pembayaran',
      subtitle: 'Support QRIS, cash, transfer, e-wallet.\nTotal & kembalian jelas, minim salah input.',
      icon: Icons.receipt_long_rounded,
    ),
    _OnbData(
      title: 'Laporan & kontrol',
      subtitle: 'Pantau transaksi harian & produk terlaris.\nData rapi, keputusan jadi lebih cepat.',
      icon: Icons.bar_chart_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 1);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortest = size.shortestSide;
    final isTablet = shortest >= 600;

    final heroH = (size.height * (isTablet ? 0.50 : 0.46))
        .clamp(280.0, isTablet ? 460.0 : 380.0)
        .toDouble();

    final contentMaxW = isTablet ? 720.0 : double.infinity;
    final illus = isTablet ? 320.0 : 250.0;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _FixedOnboardBackground(heroHeight: heroH),
            ),
            Column(
              children: [
                // HEADER
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.22)),
                              ),
                              child: Image.asset('assets/logo/mager_logo.png', fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Mager Coffee x Caffeine Meet Up',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _GlassTextButton(
                        text: 'Skip',
                        onTap: _finish,
                      ),
                    ],
                  ),
                ),

                // Body pages
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxW),
                      child: PageView.builder(
                        controller: _pc,
                        itemCount: pages.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (_, i) {
                          final p = pages[i];
                          return _OnboardContent(
                            data: p,
                            illustrationSize: illus,
                            isTablet: isTablet,
                            titleColor: _titleText,
                            bodyColor: _bodyText,
                          )
                              .animate()
                              .fadeIn(duration: 220.ms)
                              .slideY(begin: 0.03, end: 0, duration: 240.ms, curve: Curves.easeOut);
                        },
                      ),
                    ),
                  ),
                ),

                // Footer controls (Back • Dots(center) • Next)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxW),
                      child: SizedBox(
                        height: 50,
                        child: Row(
                          children: [
                            SizedBox(
                              height: 50,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                child: _index > 0
                                    ? OutlinedButton(
                                        key: const ValueKey('footerBack'),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: _primary, width: 1.4),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          padding: const EdgeInsets.symmetric(horizontal: 18),
                                        ),
                                        onPressed: () {
                                          _pc.previousPage(
                                            duration: const Duration(milliseconds: 280),
                                            curve: Curves.easeOut,
                                          );
                                        },
                                        child: const Text(
                                          'Back',
                                          style: TextStyle(fontWeight: FontWeight.w900),
                                        ),
                                      )
                                    : const SizedBox(key: ValueKey('footerSpacer'), width: 88),
                              ),
                            ),

                            // ✅ dots di tengah-tengah
                            Expanded(
                              child: Center(
                                child: _Dots(count: pages.length, index: _index),
                              ),
                            ),

                            SizedBox(
                              height: 50,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(horizontal: 22),
                                ),
                                onPressed: () async {
                                  if (_index < pages.length - 1) {
                                    _pc.nextPage(
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeOut,
                                    );
                                  } else {
                                    await _finish();
                                  }
                                },
                                child: Text(
                                  _index == pages.length - 1 ? 'Get Started' : 'Next',
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardContent extends StatelessWidget {
  const _OnboardContent({
    required this.data,
    required this.illustrationSize,
    required this.isTablet,
    required this.titleColor,
    required this.bodyColor,
  });

  final _OnbData data;
  final double illustrationSize;
  final bool isTablet;
  final Color titleColor;
  final Color bodyColor;

  @override
  Widget build(BuildContext context) {
    // ✅ konten (gambar+text) ditaruh lebih ke area putih bawah wave
    final topGap = isTablet ? 138.0 : 126.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          SizedBox(height: topGap),

          _IllustrationCard(
            imageAsset: data.imageAsset,
            icon: data.icon,
            size: illustrationSize,
            isTablet: isTablet,
          ),

          const SizedBox(height: 14),

          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 30 : 26,
              fontWeight: FontWeight.w900,
              color: titleColor,
              height: 1.05,
            ),
          )
              .animate()
              .fadeIn(duration: 220.ms)
              .slideY(begin: 0.14, end: 0, duration: 260.ms, curve: Curves.easeOut),

          const SizedBox(height: 10),

          Text(
            data.subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 15.2 : 14,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: bodyColor,
            ),
          ).animate().fadeIn(delay: 70.ms, duration: 240.ms),

          SizedBox(height: isTablet ? 24 : 18),
        ],
      ),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({
    required this.imageAsset,
    required this.icon,
    required this.size,
    required this.isTablet,
  });

  final String? imageAsset;
  final IconData icon;
  final double size;
  final bool isTablet;

  static const _primary = Color(0xFF2F6BFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(isTablet ? 18 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(isTablet ? 34 : 30),
        boxShadow: const [
          BoxShadow(blurRadius: 30, offset: Offset(0, 18), color: Color(0x22000000)),
        ],
      ),
      child: Center(
        child: imageAsset != null
            ? Image.asset(imageAsset!, fit: BoxFit.contain)
            : Container(
                width: isTablet ? 120 : 104,
                height: isTablet ? 120 : 104,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(isTablet ? 34 : 30),
                  boxShadow: const [
                    BoxShadow(blurRadius: 20, offset: Offset(0, 12), color: Color(0x22000000)),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: isTablet ? 60 : 52),
              ),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .moveY(begin: 0, end: -10, duration: 900.ms, curve: Curves.easeInOut)
        .then()
        .moveY(begin: -10, end: 0, duration: 900.ms, curve: Curves.easeInOut);
  }
}

/// background fixed + 3 layer wave animasi
class _FixedOnboardBackground extends StatefulWidget {
  const _FixedOnboardBackground({required this.heroHeight});
  final double heroHeight;

  @override
  State<_FixedOnboardBackground> createState() => _FixedOnboardBackgroundState();
}

class _FixedOnboardBackgroundState extends State<_FixedOnboardBackground> with TickerProviderStateMixin {
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
                  Color(0xFF6B4DE6),
                  Color(0xFF7AA6FF),
                ],
                stops: [0.0, 0.48, 1.0],
              ),
            ),
          ),
        ),
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
        Positioned(
          left: 0,
          right: 0,
          top: widget.heroHeight - 165,
          height: 200,
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
                      base: 78,
                      phase: 0.0,
                    ),
                  ),
                  CustomPaint(
                    size: Size.infinite,
                    painter: _AnimatedWavePainter(
                      color: const Color(0xFFEAF2FF).withOpacity(0.75),
                      t: t,
                      amp: 18,
                      base: 86,
                      phase: 1.2,
                    ),
                  ),
                  CustomPaint(
                    size: Size.infinite,
                    painter: _AnimatedWavePainter(
                      color: const Color(0xFFF6FAFF),
                      t: t,
                      amp: 22,
                      base: 94,
                      phase: 2.0,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Positioned.fill(
          top: widget.heroHeight - 18,
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

    dot(size.width * 0.10 + math.sin(a) * 8, size.height * 0.22 + math.cos(a) * 10, 12, 0.16);
    dot(size.width * 0.16 + math.cos(a * 1.1) * 10, size.height * 0.36 + math.sin(a * 0.9) * 8, 16, 0.10);
    dot(size.width * 0.22 + math.sin(a * 0.8) * 10, size.height * 0.14 + math.cos(a * 1.2) * 8, 10, 0.14);

    dot(size.width * 0.86 + math.cos(a * 1.0) * 10, size.height * 0.20 + math.sin(a * 1.1) * 10, 14, 0.14);
    dot(size.width * 0.80 + math.sin(a * 0.9) * 10, size.height * 0.34 + math.cos(a * 1.05) * 8, 18, 0.10);
    dot(size.width * 0.92 + math.sin(a * 0.7) * 8, size.height * 0.30 + math.cos(a * 0.9) * 10, 10, 0.12);
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
  bool shouldRepaint(covariant _AnimatedWavePainter oldDelegate) => oldDelegate.t != t || oldDelegate.color != color;
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 6),
          height: 8,
          width: active ? 18 : 8,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2F6BFF) : const Color(0xFFBFDBFE),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _GlassTextButton extends StatelessWidget {
  const _GlassTextButton({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _OnbData {
  final String title;
  final String subtitle;
  final String? imageAsset;
  final IconData icon;

  const _OnbData({
    required this.title,
    required this.subtitle,
    this.imageAsset,
    required this.icon,
  });
}
