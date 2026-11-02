import 'dart:async';
import 'package:flutter/material.dart';

/// Shortcut for cascading reveals: item 0 appears first, then 1, 2, ...
/// Capped so very long lists don't make the last items wait forever.
Widget staggerIn(
  int index,
  Widget child, {
  int baseMs = 150,
  int stepMs = 90,
  int maxSteps = 10,
}) {
  final step = index < maxSteps ? index : maxSteps;
  return FadeSlideIn(
    delay: Duration(milliseconds: baseMs + step * stepMs),
    child: child,
  );
}

/// Fades, slides up and (optionally) scales its child into view.
/// Use [delay] to stagger several of these into a cascading reveal.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// How many pixels below its final position the child starts.
  final double slideY;

  /// Starting scale (1.0 = no scale animation).
  final double scaleFrom;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 650),
    this.slideY = 36,
    this.scaleFrom = 1.0,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t =
      CurvedAnimation(parent: _controller, curve: widget.curve);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.slideY),
            child: Transform.scale(
              scale: widget.scaleFrom + (1 - widget.scaleFrom) * v,
              child: child,
            ),
          ),
        );
      },
    );
  }
}