import 'package:flutter/material.dart';

/// A wrapper widget that provides an intuitive swipe-from-left-to-right gesture
/// to navigate back across any screen in Socratiq.
///
/// Features:
/// - Works on both Android and iOS seamlessly.
/// - Generous touch activation area from the left edge (up to 90 logical pixels).
/// - Triggers when dragged right by > 65px or flicked rightward with velocity > 280.
/// - Gracefully falls back to [fallbackRoute] (default '/home') if the route stack cannot pop.
class SwipeBackWrapper extends StatefulWidget {
  final Widget child;
  final String? fallbackRoute;
  final bool enabled;

  const SwipeBackWrapper({
    super.key,
    required this.child,
    this.fallbackRoute = '/home',
    this.enabled = true,
  });

  @override
  State<SwipeBackWrapper> createState() => _SwipeBackWrapperState();
}

class _SwipeBackWrapperState extends State<SwipeBackWrapper> {
  double _dragDistance = 0.0;
  bool _isEligibleDrag = false;

  void _handleDragStart(DragStartDetails details) {
    if (!widget.enabled) return;
    // Allow swipe to initiate anywhere in the left 90px of the screen
    if (details.globalPosition.dx <= 90.0) {
      _dragDistance = 0.0;
      _isEligibleDrag = true;
    } else {
      _isEligibleDrag = false;
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isEligibleDrag) return;
    _dragDistance += details.primaryDelta ?? 0.0;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isEligibleDrag) return;
    _isEligibleDrag = false;

    final velocity = details.primaryVelocity ?? 0.0;
    // Trigger if dragged right by > 65px or flicked right with velocity > 280
    if (_dragDistance > 65.0 || velocity > 280.0) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else if (widget.fallbackRoute != null) {
        Navigator.pushReplacementNamed(context, widget.fallbackRoute!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: widget.child,
    );
  }
}
