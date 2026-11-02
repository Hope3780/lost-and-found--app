import 'dart:async';
import 'package:flutter/material.dart';

class TimelineStep {
  final String label;

  /// Plain-language explanation of what this stage means.
  final String description;

  const TimelineStep(this.label, this.description);
}

/// Vertical progress tracker with an explanation under every stage.
/// The line fills step by step when it first appears, and animates forward
/// again whenever [current] changes (for example when Protection Services
/// updates the status in real time).
class StatusTimeline extends StatefulWidget {
  final List<TimelineStep> steps;

  /// Index of the step the item is at right now.
  final int current;

  /// When true the timeline stops at the first step and ends in a red
  /// "Unsuccessful Report" step.
  final bool rejected;

  /// Colour of the pulsing "you are here" step.
  final Color currentColor;

  /// Wait before the fill animation starts (lets the surrounding
  /// fade-in finish first).
  final Duration delay;

  const StatusTimeline({
    super.key,
    required this.steps,
    required this.current,
    this.rejected = false,
    this.currentColor = const Color(0xFFE5A823),
    this.delay = const Duration(milliseconds: 700),
  });

  // ---------- Shared end state ----------
  static const rejectedStep = TimelineStep(
    'Unsuccessful Report',
    'Protection Services could not approve this report, so there are no '
        'further steps. Check the note on this page, or visit Protection '
        'Services to find out why.',
  );

  // ---------- Found items ----------
  static const foundSteps = [
    TimelineStep(
      'Pending',
      'Successfully reported.',
    ),
    TimelineStep(
      'Under review',
      'Protection Services is verifying the reported item.',
    ),
    TimelineStep(
      'Available for Collection',
      'The item is approved and ready for collection.',
    ),
    TimelineStep(
      'Collected',
      'The item has been handed back to its rightful owner & the report is closed.',
    ),
  ];

  // ---------- Lost items ----------
  static const lostSteps = [
    TimelineStep(
      'Pending',
      'Successfully reported.',
    ),
    TimelineStep(
      'Under review',
      'Protection Services is verifying the reported item.',
    ),
    TimelineStep(
      'Available for Collection',
      'The item is approved and ready for collection.',
    ),
    TimelineStep(
      'Collected',
      'The item has been handed back to its rightful owner & the report is closed.',
    ),
  ];

  // Maps the database status onto the four stages
  static int _stage(String status) {
    switch (status) {
      case 'under_review':
      case 'verified':
      case 'item_found':
      case 'claim_pending':
        return 1;
      case 'available_for_collection':
        return 2;
      case 'returned':
        return 3;
      default: // logged, pending
        return 0;
    }
  }

  static int foundIndex(String status) => _stage(status);
  static int lostIndex(String status) => _stage(status);

  @override
  State<StatusTimeline> createState() => _StatusTimelineState();
}

class _StatusTimelineState extends State<StatusTimeline>
    with SingleTickerProviderStateMixin {
  static const _done = Color(0xFF66BB6A);
  static const _failed = Color(0xFFEF5350);
  static const _track = Color(0x24FFFFFF);
  static const _idleNode = Color(0x38FFFFFF);
  static const _idleText = Color(0xFF8795A6);
  static const _idleBody = Color(0xFF6F7E91);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  Timer? _timer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _started = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.rejected
        ? [widget.steps.first, StatusTimeline.rejectedStep]
        : widget.steps;
    final current =
        widget.rejected ? 1 : widget.current.clamp(0, steps.length - 1);

    // p walks from -1 (nothing shown) up to the current step index.
    final target = _started ? current.toDouble() : -1.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: Duration(milliseconds: 500 + 380 * current),
      curve: Curves.easeInOut,
      builder: (context, p, _) {
        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final pulse = Curves.easeInOut.transform(_pulse.value);
            return Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _row(i, steps, current, p, pulse),
              ],
            );
          },
        );
      },
    );
  }

  Widget _row(
    int i,
    List<TimelineStep> steps,
    int current,
    double p,
    double pulse,
  ) {
    final isLast = i == steps.length - 1;
    final reveal = (p - i + 1).clamp(0.0, 1.0); // node pops in
    final lineFill = isLast ? 0.0 : (p - i).clamp(0.0, 1.0);
    final reached = reveal >= 1.0;
    final isCurrent = i == current;
    final failed = widget.rejected && isCurrent;
    final finished = isCurrent && isLast && !widget.rejected;
    final inProgress = isCurrent && !failed && !finished;

    final Color nodeColor;
    if (failed) {
      nodeColor = _failed;
    } else if (inProgress) {
      nodeColor = widget.currentColor;
    } else {
      nodeColor = _done;
    }

    final fill = Color.lerp(_idleNode, nodeColor, reveal)!;
    final pop = 0.55 + 0.45 * Curves.easeOutBack.transform(reveal);
    final glow = inProgress && reached;

    // The current step reads brightest; finished steps a little softer;
    // steps still to come stay dim but readable.
    final bodyTarget =
        isCurrent ? const Color(0xFFDCE4EE) : const Color(0xFFA9B6C6);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Stack(
              children: [
                if (!isLast)
                  Positioned(
                    top: 28,
                    bottom: 4,
                    left: 12.5,
                    width: 3,
                    child: Stack(
                      children: [
                        const Positioned.fill(child: ColoredBox(color: _track)),
                        Align(
                          alignment: Alignment.topCenter,
                          child: FractionallySizedBox(
                            heightFactor: lineFill,
                            widthFactor: 1,
                            child: const ColoredBox(color: _done),
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 2,
                  child: Transform.scale(
                    scale: pop,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fill,
                        boxShadow: glow
                            ? [
                                BoxShadow(
                                  color: nodeColor.withValues(
                                      alpha: 0.30 + 0.30 * pulse),
                                  blurRadius: 8 + 10 * pulse,
                                  spreadRadius: 1 + 3 * pulse,
                                ),
                              ]
                            : null,
                      ),
                      child: Opacity(
                        opacity: reveal,
                        child: Center(
                          child: inProgress
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : Icon(
                                  failed ? Icons.close : Icons.check,
                                  size: 15,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1, bottom: isLast ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          steps[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color.lerp(_idleText, Colors.white, reveal),
                            fontSize: 16,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (inProgress) ...[
                        const SizedBox(width: 10),
                        Opacity(
                          opacity: reveal,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: nodeColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'NOW',
                              style: TextStyle(
                                color: nodeColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    steps[i].description,
                    style: TextStyle(
                      color: Color.lerp(_idleBody, bodyTarget, reveal),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
