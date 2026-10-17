import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../cores/theme/app_theme.dart';

/// MechX's signature visual motif — a speedometer-style arc.
/// Reused across Splash (loading), Mechanic Earnings, and Admin
/// "completion rate" so the app has a consistent, recognizable shape
/// language instead of generic circular progress bars.
///
/// Wrapped in [RepaintBoundary] for GPU layer isolation to ensure 60/120 FPS performance.
class GaugeArc extends StatelessWidget {
  final double progress;
  final double size;
  final Color? trackColor;
  final Color? valueColor;
  final double strokeWidth;

  const GaugeArc({
    super.key,
    required this.progress,
    this.size = 110,
    this.trackColor,
    this.valueColor,
    this.strokeWidth = 8,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size * 0.56,
        child: CustomPaint(
          painter: _GaugePainter(
            progress: progress.clamp(0, 1),
            track: trackColor ?? c.gaugeTrack,
            value: valueColor ?? c.accent,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color value;
  final double strokeWidth;

  _GaugePainter({
    required this.progress,
    required this.track,
    required this.value,
    required this.strokeWidth,
  });

  static const _startAngle = math.pi; // left side (180deg)
  static const _sweepTotal = math.pi; // half circle to right side (0deg)

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.width - strokeWidth, // keep it a true semicircle based on width
    );

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final valuePaint = Paint()
      ..color = value
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startAngle, _sweepTotal, false, trackPaint);
    canvas.drawArc(
      rect,
      _startAngle,
      _sweepTotal * progress,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.value != value;
}
