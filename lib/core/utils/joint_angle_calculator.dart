import 'dart:math' as math;

import '../../domain/models/pose_models.dart';

/// Reusable geometric calculator for joint angle determination.
/// Follows rigorous vector mathematics:
///   vecA = A - Joint
///   vecC = C - Joint
///   dot = vecA · vecC
///   cos(θ) = dot / (|vecA| * |vecC|)
///   θ = acos(clamp(cos(θ), -1.0, 1.0)) * 180 / π
///
/// Convention:
/// - Angles normalized to the 0° – 180° range.
/// - Full extension for limbs (e.g. knee, elbow) is ~180°.
/// - Acute flexion approaches 0° – 90°.
class JointAngleCalculator {
  const JointAngleCalculator();

  /// Calculates the 2D geometric angle at [joint] subtended by [pointA] and [pointC].
  /// Returns null if any coordinate is null, non-finite, or if vectors have zero length.
  static double? calculateAngle(
    PoseLandmark? pointA,
    PoseLandmark? joint,
    PoseLandmark? pointC,
  ) {
    if (pointA == null || joint == null || pointC == null) return null;
    if (!pointA.isValid || !joint.isValid || !pointC.isValid) return null;

    final v1x = pointA.x - joint.x;
    final v1y = pointA.y - joint.y;
    final v2x = pointC.x - joint.x;
    final v2y = pointC.y - joint.y;

    final mag1Sq = v1x * v1x + v1y * v1y;
    final mag2Sq = v2x * v2x + v2y * v2y;

    if (mag1Sq <= 1e-9 || mag2Sq <= 1e-9) return null;

    final mag1 = math.sqrt(mag1Sq);
    final mag2 = math.sqrt(mag2Sq);

    final dot = v1x * v2x + v1y * v2y;
    final cosAngle = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);

    final angleRad = math.acos(cosAngle);
    final angleDeg = angleRad * 180.0 / math.pi;

    if (!angleDeg.isFinite) return null;
    return angleDeg.clamp(0.0, 180.0);
  }

  /// Calculates geometric angle from 2D coordinates directly.
  static double? calculateAngleFromCoords(
    double ax,
    double ay,
    double jx,
    double jy,
    double cx,
    double cy,
  ) {
    if (!ax.isFinite || !ay.isFinite || !jx.isFinite || !jy.isFinite || !cx.isFinite || !cy.isFinite) {
      return null;
    }

    final v1x = ax - jx;
    final v1y = ay - jy;
    final v2x = cx - jx;
    final v2y = cy - jy;

    final mag1Sq = v1x * v1x + v1y * v1y;
    final mag2Sq = v2x * v2x + v2y * v2y;

    if (mag1Sq <= 1e-9 || mag2Sq <= 1e-9) return null;

    final dot = v1x * v2x + v1y * v2y;
    final cosAngle = (dot / (math.sqrt(mag1Sq) * math.sqrt(mag2Sq))).clamp(-1.0, 1.0);

    final angleDeg = math.acos(cosAngle) * 180.0 / math.pi;
    if (!angleDeg.isFinite) return null;
    return angleDeg.clamp(0.0, 180.0);
  }
}

