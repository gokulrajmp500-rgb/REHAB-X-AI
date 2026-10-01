/// Kinematic outlier detector to identify and suppress physically impossible frame jumps.
/// Evaluates temporal continuity and maximum plausible angular velocities.
class OutlierDetector {
  const OutlierDetector({
    this.maxAngularVelocityDegPerSec = 750.0,
    this.maxSingleFrameJumpDeg = 45.0,
  });

  /// Maximum plausible angular velocity for human joint kinematics in degrees/sec.
  final double maxAngularVelocityDegPerSec;

  /// Maximum instantaneous jump between consecutive frames (assuming ~30fps).
  final double maxSingleFrameJumpDeg;

  /// Evaluates an angle series [angles] with corresponding [timestampsSec].
  /// Returns a sanitized list where isolated single-frame spikes are replaced by interpolated or previous values,
  /// or marked invalid.
  List<double> sanitizeAngleSeries(
    List<double> angles, {
    List<double>? timestampsSec,
  }) {
    if (angles.length < 3) return List.from(angles);

    final result = List<double>.from(angles);

    for (var i = 1; i < angles.length - 1; i++) {
      final prev = result[i - 1];
      final curr = angles[i];
      final next = angles[i + 1];

      final jumpPrev = (curr - prev).abs();
      final jumpNext = (curr - next).abs();
      final baseDiff = (next - prev).abs();

      // Check if current is a spike: both jumps from previous and next are large,
      // but previous and next are close together (e.g. 82° -> 171° -> 84°)
      if (jumpPrev > maxSingleFrameJumpDeg &&
          jumpNext > maxSingleFrameJumpDeg &&
          baseDiff < maxSingleFrameJumpDeg) {
        // Outlier spike detected! Smooth with linear interpolation between prev and next
        result[i] = (prev + next) / 2.0;
        continue;
      }

      // Check velocity bound if timestamps provided
      if (timestampsSec != null && timestampsSec.length == angles.length) {
        final dt = timestampsSec[i] - timestampsSec[i - 1];
        if (dt > 1e-4) {
          final velocity = jumpPrev / dt;
          if (velocity > maxAngularVelocityDegPerSec && baseDiff < maxSingleFrameJumpDeg) {
            result[i] = (prev + next) / 2.0;
          }
        }
      }
    }

    return result;
  }

  /// Checks whether a single incoming [currentAngle] at [currentTimestampSec] represents
  /// an impossible jump relative to [previousAngle] at [previousTimestampSec].
  bool isOutlierJump({
    required double currentAngle,
    required double previousAngle,
    required double currentTimestampSec,
    required double previousTimestampSec,
  }) {
    final dt = currentTimestampSec - previousTimestampSec;
    final delta = (currentAngle - previousAngle).abs();

    if (delta > maxSingleFrameJumpDeg * 2) return true;
    if (dt > 1e-4) {
      final velocity = delta / dt;
      if (velocity > maxAngularVelocityDegPerSec * 1.5) return true;
    }
    return false;
  }
}
