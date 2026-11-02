import 'package:flutter/material.dart';

/// Top-right CUT logo shown on every screen after the welcome page:
/// the original logo (assets/images/cut_logo.png) on its light grey tile.
///
/// [size] and [toolbarHeight] are used by every screen's top bar, so changing
/// them here resizes the logo everywhere at once.
class CutLogoBadge extends StatelessWidget {
  const CutLogoBadge({super.key});

  /// Logo tile size (logical pixels)
  static const double size = 60;

  /// Top bar height that leaves room for the logo (56 is Flutter's default)
  static const double toolbarHeight = 60;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 250, 251, 251),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Image.asset(
        'assets/images/CUT_medium.jpg',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.school, color: Color(0xFF17396A)),
      ),
    );
  }
}
