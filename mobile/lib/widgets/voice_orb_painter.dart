import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app_theme.dart';

class WireframeOrbPainter extends CustomPainter {
  final double rotationAngle;
  final double scale;

  WireframeOrbPainter({required this.rotationAngle, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * scale;

    final opacities = [0.9, 0.7, 0.5, 0.7, 0.5, 0.3];
    final rotations = [0, 30, 60, 90, 120, 150];

    for (int i = 0; i < rotations.length; i++) {
      final paint = Paint()
        ..color = AppTheme.primaryBlue.withOpacity(opacities[i])
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      final angle = (rotations[i] * math.pi / 180) + rotationAngle;
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2,
          height: radius * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }

    // Outer circle
    final outerPaint = Paint()
      ..color = AppTheme.primaryBlue.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, outerPaint);
  }

  @override
  bool shouldRepaint(WireframeOrbPainter old) =>
      old.rotationAngle != rotationAngle || old.scale != scale;
}
