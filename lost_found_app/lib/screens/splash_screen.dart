import 'package:flutter/material.dart';

/// Opening sequence: the CUT logo scales in with a pulse ring, a light sweep
/// crosses the title, the tagline spreads out, then the whole scene zooms
/// towards the viewer and fades to reveal the app.
///
/// [onReveal] fires just before the fade starts, so the app underneath can
/// be built in time. [onDone] fires when the splash can be removed.
class SplashScreen extends StatefulWidget {
  final VoidCallback onReveal;
  final VoidCallback onDone;

  const SplashScreen({
    super.key,
    required this.onReveal,
    required this.onDone,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF07131F);
  static const _accent = Color(0xFF8C8CFF);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  bool _started = false;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_revealed && _c.value >= 0.74) {
        _revealed = true;
        widget.onReveal();
      }
    });
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Respect the system "reduce motion" setting: skip straight to the app
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onReveal();
        widget.onDone();
      });
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Maps the overall 0..1 timeline onto a sub-range, with an easing curve.
  double _seg(double t, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0).toDouble());

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final logoIn = _seg(t, 0.0, 0.32, Curves.easeOutBack);
          final logoFade = _seg(t, 0.0, 0.18);
          final ring = _seg(t, 0.16, 0.62, Curves.easeOutCubic);
          final titleIn = _seg(t, 0.26, 0.48, Curves.easeOutCubic);
          final sweep = _seg(t, 0.36, 0.68, Curves.easeInOut);
          final settle = _seg(t, 0.62, 0.8);
          final tagline = _seg(t, 0.44, 0.72, Curves.easeOut);
          final exit = _seg(t, 0.78, 1.0, Curves.easeInCubic);

          final base = Color.lerp(
              const Color(0xFFC3CFDF), Colors.white, settle)!;

          return Opacity(
            opacity: 1 - exit,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Deep navy with a soft spotlight behind the logo
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.1),
                      radius: 0.95,
                      colors: [Color(0xFF14375E), _navy],
                    ),
                  ),
                ),
                Center(
                  child: Transform.scale(
                    scale: 1 + 0.9 * exit,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Expanding pulse ring
                              Opacity(
                                opacity: ((1 - ring) * 0.7).clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: 0.55 + 1.5 * ring,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: _accent, width: 2),
                                    ),
                                  ),
                                ),
                              ),
                              // Logo tile
                              Opacity(
                                opacity: logoFade,
                                child: Transform.scale(
                                  scale: (0.3 + 0.7 * logoIn).clamp(0.0, 2.0),
                                  child: Container(
                                    width: 104,
                                    height: 104,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _accent.withValues(
                                              alpha: 0.45 * logoFade),
                                          blurRadius: 36,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/images/CUT_medium.jpg',
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.school,
                                              size: 48,
                                              color: Color(0xFF17396A)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Title with a light sweep across it
                        Opacity(
                          opacity: titleIn,
                          child: Transform.translate(
                            offset: Offset(0, (1 - titleIn) * 18),
                            child: ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [base, Colors.white, base],
                                stops: const [0.35, 0.5, 0.65],
                                transform:
                                    _SlideGradient(-1.0 + 2.0 * sweep),
                              ).createShader(bounds),
                              child: const Text(
                                'CUT Lost & Found',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Tagline letters spread out as it fades in
                        Opacity(
                          opacity: tagline,
                          child: Text(
                            'Thinking Beyond',
                            style: TextStyle(
                              color: const Color(0xFFB8C4D4),
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 7 - 5.5 * tagline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double percent;
  const _SlideGradient(this.percent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * percent, 0, 0);
  }
}