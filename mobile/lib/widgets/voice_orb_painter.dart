import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

enum VoiceOrbState { idle, listening, thinking, speaking }

/// 3D Wireframe Orb CustomPainter representing the rotating spherical lattice
class WireframeOrbPainter extends CustomPainter {
  final double rotationAngle;
  final double scale;
  final VoiceOrbState state;
  final Color primaryColor;
  final Color accentColor;

  WireframeOrbPainter({
    required this.rotationAngle,
    required this.scale,
    this.state = VoiceOrbState.idle,
    this.primaryColor = AppTheme.primaryBlue,
    this.accentColor = AppTheme.cyanAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2.3) * scale;

    // Outer glow aura
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(state == VoiceOrbState.speaking ? 0.45 : 0.25),
          accentColor.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5));
    canvas.drawCircle(center, radius * 1.5, glowPaint);

    // Inner glowing sphere core
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(state == VoiceOrbState.speaking ? 0.35 : 0.18),
          primaryColor.withOpacity(0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.9));
    canvas.drawCircle(center, radius * 0.9, corePaint);

    final opacities = [0.85, 0.70, 0.55, 0.70, 0.55, 0.40];
    final rotations = [0, 30, 60, 90, 120, 150];

    // Longitudinal elliptical rings
    for (int i = 0; i < rotations.length; i++) {
      final ringColor = (i % 2 == 0) ? primaryColor : accentColor;
      final opacity = state == VoiceOrbState.listening
          ? (opacities[i] * 1.15).clamp(0.0, 1.0)
          : opacities[i];

      final paint = Paint()
        ..color = ringColor.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (i == 0 || i == 3) ? 2.0 : 1.4;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      final angle = (rotations[i] * math.pi / 180) + rotationAngle;
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: radius * 2,
          height: radius * (0.55 + 0.1 * math.sin(rotationAngle * 2 + i)),
        ),
        paint,
      );
      canvas.restore();
    }

    // Latitude horizontal cross-rings
    final latPaint = Paint()
      ..color = accentColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle * 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -radius * 0.35),
        width: radius * 1.7,
        height: radius * 0.35,
      ),
      latPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, radius * 0.35),
        width: radius * 1.7,
        height: radius * 0.35,
      ),
      latPaint,
    );
    canvas.restore();

    // Outer boundary ring with high-contrast accent
    final outerPaint = Paint()
      ..color = primaryColor.withOpacity(state == VoiceOrbState.speaking ? 0.7 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, outerPaint);

    // Energy nodes on outer ring
    final nodePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    for (int j = 0; j < 4; j++) {
      final nodeAngle = rotationAngle + (j * math.pi / 2);
      final nodePos = Offset(
        center.dx + radius * math.cos(nodeAngle),
        center.dy + radius * math.sin(nodeAngle),
      );
      canvas.drawCircle(nodePos, 3.0, nodePaint);
    }
  }

  @override
  bool shouldRepaint(WireframeOrbPainter old) =>
      old.rotationAngle != rotationAngle ||
      old.scale != scale ||
      old.state != state ||
      old.primaryColor != primaryColor;
}

/// Full interactive VoiceOrbWidget with integrated 4-state animations and status badge
class VoiceOrbWidget extends StatelessWidget {
  final VoiceOrbState state;
  final Animation<double> rotation;
  final Animation<double> pulse;
  final Animation<double>? ringsAnim;
  final double size;
  final String statusLabel;

  const VoiceOrbWidget({
    super.key,
    required this.state,
    required this.rotation,
    required this.pulse,
    this.ringsAnim,
    this.size = 200,
    this.statusLabel = 'Tap and hold mic to speak',
  });

  Color get _primaryColor {
    switch (state) {
      case VoiceOrbState.idle:
        return AppTheme.primaryBlue;
      case VoiceOrbState.listening:
        return AppTheme.cyanAccent;
      case VoiceOrbState.thinking:
        return AppTheme.lavenderAccent;
      case VoiceOrbState.speaking:
        return AppTheme.primaryBlue;
    }
  }

  Color get _accentColor {
    switch (state) {
      case VoiceOrbState.idle:
        return AppTheme.cyanAccent;
      case VoiceOrbState.listening:
        return Colors.white;
      case VoiceOrbState.thinking:
        return AppTheme.cyanAccent;
      case VoiceOrbState.speaking:
        return AppTheme.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Voice Orb Sphere
        SizedBox(
          width: size * 1.35,
          height: size * 1.35,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              rotation,
              pulse,
              ?ringsAnim,
            ]),
            builder: (context, _) {
              // Scale modulation based on voice state
              double currentScale = pulse.value;
              if (state == VoiceOrbState.listening && ringsAnim != null) {
                currentScale = 1.0 + (ringsAnim!.value * 0.15);
              } else if (state == VoiceOrbState.speaking) {
                currentScale = 1.0 + (0.08 * math.sin(rotation.value * 4));
              }

              // Idle gentle float offset (+/- 6dp)
              final floatOffset = state == VoiceOrbState.idle
                  ? 6.0 * math.sin(rotation.value)
                  : 0.0;

              return Transform.translate(
                offset: Offset(0, floatOffset),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Radiating listening/speaking ripple rings
                    if (state == VoiceOrbState.listening && ringsAnim != null) ...[
                      for (int r = 0; r < 3; r++)
                        Transform.scale(
                          scale: 0.95 + ((ringsAnim!.value + (r * 0.33)) % 1.0) * 0.45,
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _accentColor.withOpacity(
                                  ((1.0 - ((ringsAnim!.value + (r * 0.33)) % 1.0)) * 0.45)
                                      .clamp(0.0, 1.0),
                                ),
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                    ],

                    // Outward pulsing soundwave rings during TTS speaking
                    if (state == VoiceOrbState.speaking)
                      Transform.scale(
                        scale: 1.05 + (0.18 * math.sin(rotation.value * 3).abs()),
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.cyanAccent.withOpacity(0.35),
                              width: 2.0,
                            ),
                          ),
                        ),
                      ),

                    // Custom 3D Wireframe Sphere
                    CustomPaint(
                      size: Size(size, size),
                      painter: WireframeOrbPainter(
                        rotationAngle: rotation.value,
                        scale: currentScale,
                        state: state,
                        primaryColor: _primaryColor,
                        accentColor: _accentColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // State indicator badge
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Container(
            key: ValueKey('$state-$statusLabel'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.40),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _accentColor.withOpacity(0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.20),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
