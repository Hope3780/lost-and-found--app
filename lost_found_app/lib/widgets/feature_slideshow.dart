import 'dart:async';
import 'package:flutter/material.dart';

class _Slide {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  const _Slide(this.icon, this.accent, this.title, this.subtitle);
}

/// Auto-playing, swipeable showcase of the app's features.
/// Icons, titles and subtitles move at different speeds (parallax) and the
/// icon glows and pulses, so each slide feels like a little scene.
class FeatureSlideshow extends StatefulWidget {
  const FeatureSlideshow({super.key});

  @override
  State<FeatureSlideshow> createState() => _FeatureSlideshowState();
}

class _FeatureSlideshowState extends State<FeatureSlideshow>
    with SingleTickerProviderStateMixin {
  static const _slides = [
    _Slide(
      Icons.travel_explore,
      Color(0xFF8C8CFF),
      'Find it. Report it. Reconnect.',
      'Your campus lost & found, reimagined.',
    ),
    _Slide(
      Icons.search,
      Color(0xFF64B5F6),
      'Search everything',
      'Browse every lost and found item on campus in seconds.',
    ),
    _Slide(
      Icons.report_problem_outlined,
      Color(0xFFEF5350),
      'Lost something?',
      'Describe it, add a photo, and Protection Services will look out for it.',
    ),
    _Slide(
      Icons.camera_alt_outlined,
      Color(0xFF66BB6A),
      'Found something?',
      'Snap a photo, hand it in, and help the owner find it.',
    ),
    _Slide(
      Icons.verified_outlined,
      Color(0xFFE5A823),
      'Claim & track',
      'Claim what is yours and follow every step, live.',
    ),
  ];

  final _controller = PageController();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 4200), (_) {
      if (!_controller.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _timer?.cancel(); // the student took over
    } else if (n is ScrollEndNotification) {
      if (_timer == null || !_timer!.isActive) _startTimer();
    }
    return false;
  }

  Widget _slideView(int i) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _pulse]),
      builder: (context, _) {
        double page = _index.toDouble();
        if (_controller.hasClients && _controller.position.haveDimensions) {
          page = _controller.page ?? page;
        }
        final delta = i - page; // -1 (left) … 0 (centre) … 1 (right)
        final dist = delta.abs().clamp(0.0, 1.0);
        final slide = _slides[i];
        final pulse = Curves.easeInOut.transform(_pulse.value);

        return Opacity(
          opacity: (1 - dist * 1.3).clamp(0.0, 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon: moves fastest, shrinks as it leaves
              Transform.translate(
                offset: Offset(delta * 140, 0),
                child: Transform.scale(
                  scale: (1 - dist * 0.45) * (1 + pulse * 0.05),
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          slide.accent.withValues(alpha: 0.35),
                          slide.accent.withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: slide.accent.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: slide.accent
                              .withValues(alpha: 0.25 + pulse * 0.3),
                          blurRadius: 24 + pulse * 22,
                          spreadRadius: 2 + pulse * 5,
                        ),
                      ],
                    ),
                    child: Icon(slide.icon, size: 50, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              // Title: medium parallax
              Transform.translate(
                offset: Offset(delta * 80, 0),
                child: Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Subtitle: slowest
              Transform.translate(
                offset: Offset(delta * 40, 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    slide.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB8C4D4),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 250,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Center(child: _slideView(i)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _index ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _index
                      ? _slides[i].accent
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}