import 'package:flutter/material.dart';

/// Opens [url] full screen with pinch-to-zoom, double-tap zoom and
/// swipe-down-to-close. Pass the same [heroTag] as the photo on the
/// previous screen so the picture grows out of it.
Future<void> openPhotoViewer(
  BuildContext context, {
  required String url,
  String? heroTag,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) =>
          PhotoViewerScreen(url: url, heroTag: heroTag),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class PhotoViewerScreen extends StatefulWidget {
  final String url;
  final String? heroTag;

  const PhotoViewerScreen({super.key, required this.url, this.heroTag});

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _zoomController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Animation<Matrix4>? _zoomAnimation;

  Offset _doubleTapAt = Offset.zero;
  double _dragY = 0;
  bool _dragging = false;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(() {
      final zoomed = _transform.value.getMaxScaleOnAxis() > 1.02;
      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
    });
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _onZoomTick() {
    final value = _zoomAnimation?.value;
    if (value != null) _transform.value = value;
  }

  void _toggleZoom() {
    const scale = 2.6;
    final Matrix4 end;
    if (_zoomed) {
      end = Matrix4.identity();
    } else {
      end = Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(
          -_doubleTapAt.dx * (scale - 1),
          -_doubleTapAt.dy * (scale - 1),
          0,
        );
    }
    _zoomAnimation?.removeListener(_onZoomTick);
    _zoomAnimation = Matrix4Tween(begin: _transform.value, end: end).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
    )..addListener(_onZoomTick);
    _zoomController.forward(from: 0);
  }

  void _endDrag(DragEndDetails details) {
    final fast = details.velocity.pixelsPerSecond.dy.abs() > 900;
    if (_dragY.abs() > 110 || fast) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _dragging = false;
        _dragY = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final backdrop = (0.94 - _dragY.abs() / 500).clamp(0.35, 0.94).toDouble();

    Widget image = Image.network(
      widget.url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      },
      errorBuilder: (_, __, ___) => const Icon(
        Icons.broken_image_outlined,
        color: Colors.white54,
        size: 64,
      ),
    );
    if (widget.heroTag != null) {
      image = Hero(tag: widget.heroTag!, child: image);
    }

    return Material(
      color: Colors.black.withValues(alpha: backdrop),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
            onDoubleTap: _toggleZoom,
            // Swipe down/up to close, only while not zoomed in
            onVerticalDragStart:
                _zoomed ? null : (_) => setState(() => _dragging = true),
            onVerticalDragUpdate: _zoomed
                ? null
                : (d) => setState(() => _dragY += d.delta.dy),
            onVerticalDragEnd: _zoomed ? null : _endDrag,
            child: AnimatedContainer(
              duration:
                  _dragging ? Duration.zero : const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, _dragY, 0),
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 5,
                child: Center(child: image),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}