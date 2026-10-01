import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AnatomicalJoint {
  neck,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  spine,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

class BodySilhouettePainter extends CustomPainter {
  BodySilhouettePainter({
    this.selectedJoint,
    this.highlightedJoints = const {},
    this.activeJointColor = AppColors.cyan,
    this.showSkeletalGuide = true,
    this.jointAngles = const {},
  });

  final AnatomicalJoint? selectedJoint;
  final Set<AnatomicalJoint> highlightedJoints;
  final Color activeJointColor;
  final bool showSkeletalGuide;
  final Map<AnatomicalJoint, double> jointAngles;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.height / 380;

    final silhouettePaint = Paint()
      ..color = AppColors.line.withAlpha(160)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.muted.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw stylized anatomical athlete silhouette
    // Head
    final headCenter = Offset(cx, cy - 140 * scale);
    canvas.drawCircle(headCenter, 20 * scale, silhouettePaint);
    canvas.drawCircle(headCenter, 20 * scale, borderPaint);

    // Torso / Spine
    final neck = Offset(cx, cy - 115 * scale);
    final midChest = Offset(cx, cy - 70 * scale);
    final pelvis = Offset(cx, cy - 10 * scale);

    // Shoulders
    final lShoulder = Offset(cx - 45 * scale, cy - 105 * scale);
    final rShoulder = Offset(cx + 45 * scale, cy - 105 * scale);

    // Elbows
    final lElbow = Offset(cx - 65 * scale, cy - 40 * scale);
    final rElbow = Offset(cx + 65 * scale, cy - 40 * scale);

    // Wrists
    final lWrist = Offset(cx - 75 * scale, cy + 20 * scale);
    final rWrist = Offset(cx + 75 * scale, cy + 20 * scale);

    // Hips
    final lHip = Offset(cx - 32 * scale, cy - 5 * scale);
    final rHip = Offset(cx + 32 * scale, cy - 5 * scale);

    // Knees
    final lKnee = Offset(cx - 35 * scale, cy + 70 * scale);
    final rKnee = Offset(cx + 35 * scale, cy + 70 * scale);

    // Ankles
    final lAnkle = Offset(cx - 38 * scale, cy + 145 * scale);
    final rAnkle = Offset(cx + 38 * scale, cy + 145 * scale);

    // Torso body contour
    final torsoPath = Path()
      ..moveTo(lShoulder.dx, lShoulder.dy)
      ..lineTo(rShoulder.dx, rShoulder.dy)
      ..lineTo(rHip.dx + 6 * scale, rHip.dy)
      ..lineTo(lHip.dx - 6 * scale, lHip.dy)
      ..close();
    canvas.drawPath(torsoPath, silhouettePaint);
    canvas.drawPath(torsoPath, borderPaint);

    // Skeletal guide lines
    if (showSkeletalGuide) {
      final skeletonPaint = Paint()
        ..color = AppColors.cyan.withAlpha(80)
        ..strokeWidth = 2.0 * scale
        ..style = PaintingStyle.stroke;

      // Spine
      canvas.drawLine(neck, pelvis, skeletonPaint);
      // Clavicle
      canvas.drawLine(lShoulder, rShoulder, skeletonPaint);
      // Arms
      canvas.drawLine(lShoulder, lElbow, skeletonPaint);
      canvas.drawLine(lElbow, lWrist, skeletonPaint);
      canvas.drawLine(rShoulder, rElbow, skeletonPaint);
      canvas.drawLine(rElbow, rWrist, skeletonPaint);
      // Pelvis bar
      canvas.drawLine(lHip, rHip, skeletonPaint);
      // Legs
      canvas.drawLine(lHip, lKnee, skeletonPaint);
      canvas.drawLine(lKnee, lAnkle, skeletonPaint);
      canvas.drawLine(rHip, rKnee, skeletonPaint);
      canvas.drawLine(rKnee, rAnkle, skeletonPaint);
    }

    // Joint landmarks map
    final joints = <AnatomicalJoint, Offset>{
      AnatomicalJoint.neck: neck,
      AnatomicalJoint.leftShoulder: lShoulder,
      AnatomicalJoint.rightShoulder: rShoulder,
      AnatomicalJoint.leftElbow: lElbow,
      AnatomicalJoint.rightElbow: rElbow,
      AnatomicalJoint.leftWrist: lWrist,
      AnatomicalJoint.rightWrist: rWrist,
      AnatomicalJoint.spine: midChest,
      AnatomicalJoint.leftHip: lHip,
      AnatomicalJoint.rightHip: rHip,
      AnatomicalJoint.leftKnee: lKnee,
      AnatomicalJoint.rightKnee: rKnee,
      AnatomicalJoint.leftAnkle: lAnkle,
      AnatomicalJoint.rightAnkle: rAnkle,
    };

    // Draw Joint Nodes
    for (final entry in joints.entries) {
      final joint = entry.key;
      final pos = entry.value;
      final isSelected = selectedJoint == joint;
      final isHighlighted = highlightedJoints.contains(joint);

      final nodeColor = isSelected
          ? activeJointColor
          : isHighlighted
              ? AppColors.green
              : AppColors.cyan.withAlpha(150);

      final radius = (isSelected ? 9.0 : 6.0) * scale;

      // Glowing outer ring for selected/highlighted joint
      if (isSelected || isHighlighted) {
        final glowPaint = Paint()
          ..color = nodeColor.withAlpha(60)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, radius * 2.0, glowPaint);
      }

      final nodePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, radius, nodePaint);

      final nodeRing = Paint()
        ..color = Colors.white.withAlpha(200)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(pos, radius, nodeRing);

      // Display angle value badge if provided
      if (jointAngles.containsKey(joint)) {
        final angle = jointAngles[joint]!;
        final textSpan = TextSpan(
          text: '${angle.toStringAsFixed(0)}°',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 10 * scale,
            fontWeight: FontWeight.bold,
          ),
        );
        final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
        final textOffset = Offset(pos.dx + 12 * scale, pos.dy - 6 * scale);
        tp.paint(canvas, textOffset);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BodySilhouettePainter oldDelegate) {
    return oldDelegate.selectedJoint != selectedJoint ||
        oldDelegate.highlightedJoints != highlightedJoints ||
        oldDelegate.jointAngles != jointAngles;
  }
}
