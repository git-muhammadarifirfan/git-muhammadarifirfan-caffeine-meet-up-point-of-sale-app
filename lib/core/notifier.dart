import 'dart:async';
import 'package:flutter/material.dart';

/// Pemakaian:
/// notify(context, "Berhasil disimpan");
/// notify(context, "Gagal menyimpan", error: true);
/// notify(context, "Sedang sinkron...", info: true);
void notify(
  BuildContext context,
  String msg, {
  bool error = false,
  bool info = false,
  Duration duration = const Duration(milliseconds: 2600),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
  if (overlay == null) return;

  // tutup toast sebelumnya (aman)
  _ToastOverlayHost.instance.hide();

  // token untuk cegah toast lama menutup toast baru
  final token = _ToastOverlayHost.instance.nextToken();

  final entry = OverlayEntry(
    builder: (_) => _ToastOverlayHost(
      token: token,
      message: msg,
      kind: error
          ? _ToastKind.error
          : info
              ? _ToastKind.info
              : _ToastKind.success,
      duration: duration,
    ),
  );

  _ToastOverlayHost.instance.attach(entry, overlay, token);
}

enum _ToastKind { success, error, info }

class _ToastOverlayHost extends StatefulWidget {
  final int token;
  final String message;
  final _ToastKind kind;
  final Duration duration;

  const _ToastOverlayHost({
    super.key,
    required this.token,
    required this.message,
    required this.kind,
    required this.duration,
  });

  static final _ToastOverlayHostController instance = _ToastOverlayHostController();

  @override
  State<_ToastOverlayHost> createState() => _ToastOverlayHostState();
}

class _ToastOverlayHostController {
  OverlayEntry? _entry;
  int _token = 0;
  bool _removing = false;

  int nextToken() => ++_token;

  void attach(OverlayEntry entry, OverlayState overlay, int token) {
    // aman: bersihin dulu yang lama
    hide();

    _entry = entry;
    _token = token;
    overlay.insert(entry);
  }

  void hide({int? token}) {
    // kalau dipanggil dari toast lama, jangan ganggu toast baru
    if (token != null && token != _token) return;
    if (_removing) return;

    final entry = _entry;
    _entry = null;

    if (entry == null) return;
    if (!entry.mounted) return;

    _removing = true;

    // remove di post-frame biar aman dari assert framework
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (entry.mounted) entry.remove();
      } catch (_) {
        // ignore
      } finally {
        _removing = false;
      }
    });
  }
}

class _ToastOverlayHostState extends State<_ToastOverlayHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();

    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );

    final curveIn = CurvedAnimation(parent: _ctl, curve: Curves.easeOutCubic);
    _fade = Tween<double>(begin: 0, end: 1).animate(curveIn);
    _scale = Tween<double>(begin: 0.98, end: 1).animate(curveIn);
    _slide =
        Tween<Offset>(begin: const Offset(0.06, -0.04), end: Offset.zero).animate(curveIn);

    _ctl.forward();
    _timer = Timer(widget.duration, _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;

    _timer?.cancel();

    try {
      await _ctl.reverse();
    } catch (_) {
      // ignore
    }

    if (!mounted) return;

    // ✅ hanya tutup kalau token masih sama (biar toast lama nggak nutup toast baru)
    _ToastOverlayHost.instance.hide(token: widget.token);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final maxW = w < 420 ? w - 24 : 360.0;

    final (icon, accent, bg, border, textColor) = switch (widget.kind) {
      _ToastKind.success => (
          Icons.check_circle_rounded,
          const Color(0xFF16A34A),
          const Color(0xFF0B1220),
          const Color(0xFF1E293B),
          Colors.white,
        ),
      _ToastKind.error => (
          Icons.error_rounded,
          const Color(0xFFEF4444),
          const Color(0xFF0B1220),
          const Color(0xFF1E293B),
          Colors.white,
        ),
      _ToastKind.info => (
          Icons.info_rounded,
          const Color(0xFF3B82F6),
          const Color(0xFF0B1220),
          const Color(0xFF1E293B),
          Colors.white,
        ),
    };

    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, right: 12, left: 12),
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 18,
                              offset: Offset(0, 10),
                              color: Color(0x33000000),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: accent.withOpacity(0.35)),
                              ),
                              child: Icon(icon, color: accent, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  widget.message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                    color: textColor.withOpacity(0.95),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkResponse(
                              onTap: _close,
                              radius: 18,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: textColor.withOpacity(0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
