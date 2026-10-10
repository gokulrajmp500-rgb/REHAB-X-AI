import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/pose_models.dart';

/// Charts measured range-of-motion values for each recorded repetition.
class TemporalAngleChart extends StatelessWidget {
  const TemporalAngleChart({
    super.key,
    required this.angles,
    this.repetitionDetails = const [],
    this.jointName = 'Primary Joint',
    this.height = 180,
  });

  final List<double> angles;
  final List<RepetitionDetail> repetitionDetails;
  final String jointName;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (angles.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        child: const Text('No angle data recorded', style: TextStyle(color: AppColors.muted, fontSize: 12)),
      );
    }

    final minAngle = angles.reduce(math.min);
    final maxAngle = angles.reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$jointName ROM By Repetition'.toUpperCase(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.cyan,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Text(
              'Min: ${minAngle.toStringAsFixed(0)}°  Max: ${maxAngle.toStringAsFixed(0)}°',
              style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: CustomPaint(
            size: Size.infinite,
            painter: _AngleChartPainter(
              angles: angles,
              minAngle: minAngle,
              maxAngle: maxAngle,
              repetitionCount: repetitionDetails.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _AngleChartPainter extends CustomPainter {
  _AngleChartPainter({
    required this.angles,
    required this.minAngle,
    required this.maxAngle,
    required this.repetitionCount,
  });

  final List<double> angles;
  final double minAngle;
  final double maxAngle;
  final int repetitionCount;

  @override
  void paint(Canvas canvas, Size size) {
    if (angles.isEmpty) return;

    final gridPaint = Paint()
      ..color = AppColors.line.withAlpha(90)
      ..strokeWidth = 1.0;

    // Draw horizontal grid lines
    const gridLines = [45.0, 90.0, 135.0, 180.0];
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final deg in gridLines) {
      final y = size.height - (deg / 185.0 * size.height);
      if (y >= 0 && y <= size.height) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

        textPainter.text = TextSpan(
          text: '${deg.toInt()}°',
          style: const TextStyle(color: AppColors.muted, fontSize: 8.5),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(2, y - 10));
      }
    }

    // Path for angle curve
    final path = Path();
    final stepX = angles.length > 1 ? size.width / (angles.length - 1) : size.width;

    double getY(double deg) {
      final norm = (deg.clamp(0.0, 185.0)) / 185.0;
      return size.height - (norm * size.height);
    }

    path.moveTo(0, getY(angles.first));
    for (var i = 1; i < angles.length; i++) {
      final x = i * stepX;
      final y = getY(angles[i]);
      path.lineTo(x, y);
    }

    // Fill under curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.cyan.withAlpha(50), AppColors.cyan.withAlpha(0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = AppColors.cyan
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    // Repetition indicators
    if (repetitionCount > 1 && angles.length > 5) {
      final repStep = angles.length / repetitionCount;
      final repMarkerPaint = Paint()
        ..color = AppColors.green.withAlpha(120)
        ..strokeWidth = 1.0;

      for (var r = 1; r < repetitionCount; r++) {
        final x = r * repStep * stepX;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), repMarkerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AngleChartPainter oldDelegate) =>
      oldDelegate.angles != angles || oldDelegate.repetitionCount != repetitionCount;
}
