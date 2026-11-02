import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Welcome-screen backdrop: the campus photo drifts and zooms very slowly
/// (Ken Burns effect) under a dark blur, with a few soft lights floating up.
class CampusBackground extends StatefulWidget {
  final Widget child;

  const CampusBackground({super.key, required this.child});

  @override
  State<CampusBackground> createState() => _CampusBackgroundState();
}

class _CampusBackgroundState extends State<CampusBackground>
    with SingleTickerProviderStateMixin {
  // One slow loop drives both the photo drift and the floating lights.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  static final _particles = List.generate(22, _Particle.seeded);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Photo: blurred once (cached), then only moved/scaled each frame
        ClipRect(
          child: AnimatedBuilder(
            animation: _c,
            child: RepaintBoundary(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Image.asset(
                  'assets/images/campus.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF0B1623)),
                ),
              ),
            ),
            builder: (context, child) {
              // 0 -> 1 -> 0 smoothly over the loop
              final t = (1 - math.cos(2 * math.pi * _c.value)) / 2;
              final scale = 1.15 + 0.13 * t;
              return Transform.scale(
                scale: scale,
                child: FractionalTranslation(
                  translation: Offset(-0.045 + 0.09 * t, 0.015 - 0.03 * t),
                  child: child,
                ),
              );
            },
          ),
        ),
        // Dark overlay
        const ColoredBox(color: Color.fromRGBO(11, 22, 35, 0.65)),
        // Floating lights
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _ParticlePainter(_c, _particles),
              size: Size.infinite,
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Particle {
  final double x; // 0..1 across the screen
  final double size; // radius in logical pixels
  final int speed; // whole loops per cycle, so the loop is seamless
  final double phase;
  final double sway;

  const _Particle(this.x, this.size, this.speed, this.phase, this.sway);

  factory _Particle.seeded(int i) {
    final r = math.Random(i * 7919 + 13);
    return _Particle(
      r.nextDouble(),
      1.2 + r.nextDouble() * 2.4,
      1 + r.nextInt(3),
      r.nextDouble(),
      0.01 + r.nextDouble() * 0.035,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final Animation<double> anim;
  final List<_Particle> particles;

  _ParticlePainter(this.anim, this.particles) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    for (final p in particles) {
      final travel = (t * p.speed + p.phase) % 1.0;
      final y = 1 - travel; // drifts upward
      final sway = math.sin(2 * math.pi * (t * p.speed + p.phase)) * p.sway;
      final twinkle =
          0.5 + 0.5 * math.sin(2 * math.pi * (t * p.speed * 3 + p.phase));
      // Fade in near the bottom and out near the top
      final edge = math.sin(math.pi * y);
      final alpha = (0.08 + 0.26 * twinkle) * edge;
      if (alpha <= 0.005) continue;

      canvas.drawCircle(
        Offset((p.x + sway) * size.width, y * size.height),
        p.size,
        Paint()
          ..color = const Color(0xFFBFD4FF).withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => false;
}
