import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Full-screen "success" moment: a ring draws itself, a check mark is
/// stroked inside it, and the message fades up. Closes by itself (or on tap).
///
/// Await it, then carry on, e.g. pop the form:
///   await showSuccessCheck(context, title: 'Item reported');
Future<void> showSuccessCheck(
  BuildContext context, {
  required String title,
  String? subtitle,
  Duration hold = const Duration(milliseconds: 900),
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: title,
    barrierColor: const Color(0xE607131F),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) =>
        _SuccessCheck(title: title, subtitle: subtitle, hold: hold),
    transitionBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _SuccessCheck extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Duration hold;

  const _SuccessCheck({
    required this.title,
    required this.subtitle,
    required this.hold,
  });

  @override
  State<_SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<_SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  Timer? _timer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (!mounted) return;
      _timer = Timer(widget.hold, _close);
    });
  }

  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final pop = Curves.easeOutBack
                  .transform((t / 0.5).clamp(0.0, 1.0).toDouble());
              final glow = ((t - 0.5) / 0.4).clamp(0.0, 1.0).toDouble();
              final text = ((t - 0.55) / 0.4).clamp(0.0, 1.0).toDouble();

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: 0.7 + 0.3 * pop,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF66BB6A)
                                .withValues(alpha: 0.35 * glow),
                            blurRadius: 44,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: CustomPaint(painter: _CheckPainter(t)),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Opacity(
                    opacity: text,
                    child: Transform.translate(
                      offset: Offset(0, (1 - text) * 14),
                      child: Column(
                        children: [
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                widget.subtitle!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFB8C4D4),
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double t; // 0..1 over the whole animation
  const _CheckPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const green = Color(0xFF66BB6A);
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;

    // Soft fill that arrives once the ring has nearly closed
    final fillT = ((t - 0.45) / 0.3).clamp(0.0, 1.0).toDouble();
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = green.withValues(alpha: 0.16 * fillT),
    );

    // Ring draws itself clockwise from the top
    final ringT =
        Curves.easeInOut.transform((t / 0.55).clamp(0.0, 1.0).toDouble());
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = green;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ringT,
      false,
      stroke,
    );

    // Check mark is stroked in after the ring
    final checkT = ((t - 0.5) / 0.5).clamp(0.0, 1.0).toDouble();
    if (checkT > 0) {
      final path = Path()
        ..moveTo(size.width * 0.29, size.height * 0.53)
        ..lineTo(size.width * 0.44, size.height * 0.67)
        ..lineTo(size.width * 0.72, size.height * 0.38);
      final metric = path.computeMetrics().first;
      final drawn = metric.extractPath(
        0,
        metric.length * Curves.easeOut.transform(checkT),
      );
      canvas.drawPath(drawn, stroke);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}