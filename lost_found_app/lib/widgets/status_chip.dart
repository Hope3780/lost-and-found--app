import 'package:flutter/material.dart';

/// Small coloured pill showing a report's status, e.g. "Under review".
/// The colour follows the stage: amber while pending, blue while being
/// reviewed, green when ready or collected, red when unsuccessful.
class StatusChip extends StatelessWidget {
  final String status;
  final String label;

  const StatusChip({super.key, required this.status, required this.label});

  static (Color, Color) _colors(String status) {
    switch (status) {
      case 'under_review':
      case 'verified':
      case 'item_found':
        return (const Color(0xFFE3EEFF), const Color(0xFF1D4E9E));
      case 'claim_pending':
        return (const Color(0xFFFFF0D2), const Color(0xFF9A6700));
      case 'available_for_collection':
        return (const Color(0xFFDDF4E5), const Color(0xFF1C6B34));
      case 'returned':
        return (const Color(0xFFCDEDD9), const Color(0xFF14532D));
      case 'rejected':
        return (const Color(0xFFFDE4E1), const Color(0xFFB42318));
      default: // logged, pending
        return (const Color(0xFFFFF3D6), const Color(0xFF9A6700));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}