import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Global background, added once in main.dart.
/// The campus building now fills the whole screen behind every screen, under
/// a navy tint that is darker at the top (for the headings) and lighter at the
/// bottom, so the photo stays visible while text and cards stay readable.
class AppBackground extends StatefulWidget {
  final Widget? child;

  const AppBackground({super.key, this.child});

  static const navy = Color(0xFF07131F);

  /// Screens that want the footer hidden while they are showing (the
  /// create-account page and the home page). Each screen is its own "owner",
  /// so one screen closing can't switch off another's request.
  static final ValueNotifier<bool> hideFooter = ValueNotifier<bool>(false);
  static final Set<Object> _hiders = <Object>{};

  static void setFooterHidden(Object owner, bool hide) {
    if (hide) {
      _hiders.add(owner);
    } else {
      _hiders.remove(owner);
    }
    hideFooter.value = _hiders.isNotEmpty;
  }

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground> {
  static const navy = AppBackground.navy;

  // How blurry the photo is (higher = softer). The welcome screen uses 8; 2.5 was the original.
  static const double _blur = 25;

  // How much black is laid over the photo to darken it (0 = none, 1 = solid).
  static const double _darken = 0.30;

  // The footer fades in over the last this-many pixels of scrolling.
  static const double _fadeDistance = 60;

  // 0 = footer hidden, 1 = fully shown. Only the footer listens to this, so
  // scrolling never rebuilds the rest of the app.
  final ValueNotifier<double> _footerShown = ValueNotifier<double>(0);

  @override
  void dispose() {
    _footerShown.dispose();
    super.dispose();
  }

  // Hears the scrolling of whichever screen is on top. The footer appears
  // only when that screen is scrolled to its end (or is too short to scroll).
  bool _onNotification(Notification n) {
    ScrollMetrics? m;
    int depth = 0;
    if (n is ScrollNotification) {
      m = n.metrics;
      depth = n.depth;
    } else if (n is ScrollMetricsNotification) {
      m = n.metrics;
      depth = n.depth;
    }
    if (m != null && depth == 0 && m.axis == Axis.vertical) {
      final left = (m.maxScrollExtent - m.pixels).clamp(0.0, double.infinity);
      _footerShown.value = 1 - (left / _fadeDistance).clamp(0.0, 1.0);
    }
    return false; // let the notification carry on
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Solid dark base (shows if the photo is missing)
        const ColoredBox(color: navy),

        // Full-screen building photo, softly blurred. Cached in its own
        // layer so it is not re-blurred while screens animate on top.
        RepaintBoundary(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
            child: Image.asset(
              'assets/images/dark_bhp.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
        ),

        // Dark layer over the photo (raise _darken for a darker background)
        ColoredBox(color: Colors.black.withValues(alpha: _darken)),

        // Footer: centred at the very bottom, no box behind it. It only
        // appears once the page is scrolled to its end, so it never sits
        // over other content. It is drawn behind the screens.
        Positioned(
          left: 0,
          right: 0,
          bottom: 14 + bottomInset,
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: AppBackground.hideFooter,
              builder: (context, hidden, child) => hidden
                  ? const SizedBox.shrink()
                  : ValueListenableBuilder<double>(
                      valueListenable: _footerShown,
                      builder: (context, shown, child) =>
                          Opacity(opacity: shown, child: child),
                      child: child,
                    ),
              child: const Text(
                'CUT  •  LOST & FOUND',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD6DEE9),
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),

        if (widget.child != null)
          Positioned.fill(
            child: NotificationListener<Notification>(
              onNotification: _onNotification,
              child: widget.child!,
            ),
          ),
      ],
    );
  }
}
