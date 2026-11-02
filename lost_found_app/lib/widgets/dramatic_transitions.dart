import 'package:flutter/material.dart';

/// Cinematic page transition used for every route in the app.
///
/// The new screen rises from slightly below while scaling up and fading in.
/// The screen underneath recedes (scales down and dims) so the new page feels
/// like it is stepping in front of it.
class DramaticPageTransitionsBuilder extends PageTransitionsBuilder {
  const DramaticPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final leave = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeInOutCubic,
    );

    // Incoming page: fade + rise + scale up
    final incoming = FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: animation, curve: const Interval(0, 0.7)),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(enter),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(enter),
          child: child,
        ),
      ),
    );

    // Page underneath: recede and dim when another page covers it
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 0.95).animate(leave),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.35).animate(leave),
        child: incoming,
      ),
    );
  }
}

/// Theme entry that applies [DramaticPageTransitionsBuilder] on every platform.
const dramaticPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: DramaticPageTransitionsBuilder(),
    TargetPlatform.iOS: DramaticPageTransitionsBuilder(),
    TargetPlatform.macOS: DramaticPageTransitionsBuilder(),
    TargetPlatform.windows: DramaticPageTransitionsBuilder(),
    TargetPlatform.linux: DramaticPageTransitionsBuilder(),
    TargetPlatform.fuchsia: DramaticPageTransitionsBuilder(),
  },
);