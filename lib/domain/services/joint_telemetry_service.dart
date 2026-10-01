import 'dart:math' as math;
import '../../core/utils/joint_angle_calculator.dart';
import '../../core/widgets/body_silhouette_painter.dart';
import '../models/exercise_analysis_config.dart';
import '../models/pose_models.dart';

class JointTelemetryReport {
  const JointTelemetryReport({
    required this.joint,
    required this.displayName,
    required this.currentAngle,
    required this.rangeOfMotion,
    this.minAngle,
    this.maxAngle,
    this.consistency,
    this.bilateralDifference,
    this.observation = 'Joint angle within expected movement envelope.',
    this.isBilateral = true,
    this.confidenceLevel = 'HIGH',
    this.isAvailable = true,
  });

  final AnatomicalJoint joint;
  final String displayName;
  final double currentAngle;
  final double rangeOfMotion;
  final double? minAngle;
  final double? maxAngle;
  final double? consistency;
  final double? bilateralDifference;
  final String observation;
  final bool isBilateral;
  final String confidenceLevel;
  final bool isAvailable;
}

class JointTelemetryService {
  const JointTelemetryService();

  double? primaryAngle(PoseFrame? frame, ExerciseAnalysisConfig config) {
    if (frame == null) return null;
    final triplet = switch (config.exerciseId) {
      'squat' || 'lunge' => ('hip', 'knee', 'ankle'),
      'shoulder_flexion' || 'shoulder_abduction' => ('elbow', 'shoulder', 'hip'),
      'calf_raise' => ('knee', 'ankle', 'foot'),
      'hip_hinge' => ('shoulder', 'hip', 'knee'),
      'elbow_flexion' || 'push_up' => ('wrist', 'elbow', 'shoulder'),
      _ => null,
    };
    if (triplet == null) return null;

    double? bestAngle;
    var bestConfidence = -1.0;
    for (final side in const ['left', 'right']) {
      final points = [
        _sideLandmark(frame, side, triplet.$1),
        _sideLandmark(frame, side, triplet.$2),
        _sideLandmark(frame, side, triplet.$3),
      ];
      if (points.any((point) => point == null || !point.isValid)) continue;
      final angle = JointAngleCalculator.calculateAngle(
        points[0],
        points[1],
        points[2],
      );
      final confidence = points.fold<double>(
        0,
        (sum, point) => sum + point!.confidence,
      );
      if (angle != null && confidence > bestConfidence) {
        bestAngle = angle;
        bestConfidence = confidence;
      }
    }
    if (bestAngle != null) return bestAngle;

    return JointAngleCalculator.calculateAngle(
      frame.landmarks[triplet.$1],
      frame.landmarks[triplet.$2],
      frame.landmarks[triplet.$3],
    );
  }

  PoseLandmark? _sideLandmark(PoseFrame frame, String side, String name) {
    if (name == 'foot') {
      return frame.landmarks['${side}FootIndex'] ??
          frame.landmarks['${side}Heel'];
    }
    final key = '$side${name[0].toUpperCase()}${name.substring(1)}';
    return frame.landmarks[key];
  }

  JointTelemetryReport analyzeJoint(PoseSequence sequence, AnatomicalJoint joint) {
    if (!sequence.isSufficient) {
      return JointTelemetryReport(
        joint: joint,
        displayName: _jointName(joint),
        currentAngle: 0,
        rangeOfMotion: 0,
        observation: 'Insufficient frame data to calculate joint telemetry.',
        confidenceLevel: 'INSUFFICIENT',
        isAvailable: false,
      );
    }

    final angles = <double>[];
    for (final frame in sequence.frames) {
      final angle = _extractAngle(frame, joint);
      if (angle != null && angle.isFinite) {
        angles.add(angle);
      }
    }

    if (angles.isEmpty) {
      return JointTelemetryReport(
        joint: joint,
        displayName: _jointName(joint),
        currentAngle: 0,
        rangeOfMotion: 0,
        observation: 'Required landmarks not detected for this joint.',
        confidenceLevel: 'INSUFFICIENT',
        isAvailable: false,
      );
    }

    final currentAngle = angles.last;
    final minAngle = angles.reduce(math.min);
    final maxAngle = angles.reduce(math.max);
    final rom = maxAngle - minAngle;

    // Consistency
    final mean = angles.reduce((a, b) => a + b) / angles.length;
    final variance = angles.map((a) => math.pow(a - mean, 2)).reduce((a, b) => a + b) / angles.length;
    final consistency = (100 - math.sqrt(variance)).clamp(0.0, 100.0);

    // Bilateral difference if applicable
    double? bilateralDiff;
    final counterpart = _counterpartJoint(joint);
    if (counterpart != null) {
      final otherAngles = <double>[];
      for (final frame in sequence.frames) {
        final otherAngle = _extractAngle(frame, counterpart);
        if (otherAngle != null && otherAngle.isFinite) {
          otherAngles.add(otherAngle);
        }
      }
      if (otherAngles.isNotEmpty) {
        final otherRom = otherAngles.reduce(math.max) - otherAngles.reduce(math.min);
        final denom = math.max((rom.abs() + otherRom.abs()) / 2, 0.001);
        bilateralDiff = ((rom - otherRom).abs() / denom * 100).clamp(0.0, 100.0);
      }
    }

    String observation = 'Movement trajectory recorded.';
    if (bilateralDiff != null && bilateralDiff > 18) {
      observation = 'Small left/right movement difference observed (${bilateralDiff.toStringAsFixed(0)}%).';
    } else if (consistency >= 80) {
      observation = 'Repeatable joint kinematics observed across cycles.';
    } else {
      observation = 'Moderate movement variation observed; maintain controlled tempo.';
    }

    final ratio = angles.length / sequence.frames.length;
    final conf = sequence.dataConfidence;
    String confLevel = 'MODERATE';
    if (ratio >= 0.8 && conf >= 0.75) {
      confLevel = 'HIGH';
    } else if (ratio < 0.5 || conf < 0.55) {
      confLevel = 'LOW';
    }

    return JointTelemetryReport(
      joint: joint,
      displayName: _jointName(joint),
      currentAngle: currentAngle,
      rangeOfMotion: rom,
      minAngle: minAngle,
      maxAngle: maxAngle,
      consistency: consistency,
      bilateralDifference: bilateralDiff,
      observation: observation,
      isBilateral: counterpart != null,
      confidenceLevel: confLevel,
      isAvailable: true,
    );
  }

  Map<String, JointMetricSummary> analyzeAllKeyJoints(PoseSequence sequence) {
    const keyJoints = [
      AnatomicalJoint.leftKnee,
      AnatomicalJoint.rightKnee,
      AnatomicalJoint.leftHip,
      AnatomicalJoint.rightHip,
      AnatomicalJoint.leftShoulder,
      AnatomicalJoint.rightShoulder,
      AnatomicalJoint.leftElbow,
      AnatomicalJoint.rightElbow,
      AnatomicalJoint.leftAnkle,
      AnatomicalJoint.rightAnkle,
    ];

    final result = <String, JointMetricSummary>{};
    for (final j in keyJoints) {
      final rep = analyzeJoint(sequence, j);
      if (rep.isAvailable && rep.rangeOfMotion > 0) {
        result[rep.displayName] = JointMetricSummary(
          jointName: rep.displayName,
          currentAngle: rep.currentAngle,
          rangeOfMotion: rep.rangeOfMotion,
          minAngle: rep.minAngle,
          maxAngle: rep.maxAngle,
          symmetryDifference: rep.bilateralDifference,
          consistency: rep.consistency,
          observation: rep.observation,
          confidenceLevel: rep.confidenceLevel,
          isAvailable: true,
        );
      }
    }
    return result;
  }

  double? _extractAngle(PoseFrame frame, AnatomicalJoint joint) {
    return switch (joint) {
      AnatomicalJoint.leftKnee => _angle(frame, 'leftHip', 'leftKnee', 'leftAnkle'),
      AnatomicalJoint.rightKnee => _angle(frame, 'rightHip', 'rightKnee', 'rightAnkle'),
      AnatomicalJoint.leftHip => _angle(frame, 'leftShoulder', 'leftHip', 'leftKnee'),
      AnatomicalJoint.rightHip => _angle(frame, 'rightShoulder', 'rightHip', 'rightKnee'),
      AnatomicalJoint.leftShoulder => _angle(frame, 'leftElbow', 'leftShoulder', 'leftHip'),
      AnatomicalJoint.rightShoulder => _angle(frame, 'rightElbow', 'rightShoulder', 'rightHip'),
      AnatomicalJoint.leftElbow => _angle(frame, 'leftWrist', 'leftElbow', 'leftShoulder'),
      AnatomicalJoint.rightElbow => _angle(frame, 'rightWrist', 'rightElbow', 'rightShoulder'),
      AnatomicalJoint.leftAnkle => _angle(frame, 'leftKnee', 'leftAnkle', 'leftFootIndex') ??
          _angle(frame, 'leftKnee', 'leftAnkle', 'leftHeel'),
      AnatomicalJoint.rightAnkle => _angle(frame, 'rightKnee', 'rightAnkle', 'rightFootIndex') ??
          _angle(frame, 'rightKnee', 'rightAnkle', 'rightHeel'),
      AnatomicalJoint.neck => _angle(frame, 'leftEar', 'leftShoulder', 'leftHip'),
      AnatomicalJoint.spine => _angle(frame, 'shoulder', 'hip', 'knee'),
      _ => null,
    };
  }

  double? _angle(PoseFrame frame, String aName, String bName, String cName) {
    final a = frame.landmarks[aName];
    final b = frame.landmarks[bName];
    final c = frame.landmarks[cName];
    return JointAngleCalculator.calculateAngle(a, b, c);
  }

  AnatomicalJoint? _counterpartJoint(AnatomicalJoint joint) {
    return switch (joint) {
      AnatomicalJoint.leftKnee => AnatomicalJoint.rightKnee,
      AnatomicalJoint.rightKnee => AnatomicalJoint.leftKnee,
      AnatomicalJoint.leftHip => AnatomicalJoint.rightHip,
      AnatomicalJoint.rightHip => AnatomicalJoint.leftHip,
      AnatomicalJoint.leftShoulder => AnatomicalJoint.rightShoulder,
      AnatomicalJoint.rightShoulder => AnatomicalJoint.leftShoulder,
      AnatomicalJoint.leftElbow => AnatomicalJoint.rightElbow,
      AnatomicalJoint.rightElbow => AnatomicalJoint.leftElbow,
      AnatomicalJoint.leftAnkle => AnatomicalJoint.rightAnkle,
      AnatomicalJoint.rightAnkle => AnatomicalJoint.leftAnkle,
      AnatomicalJoint.leftWrist => AnatomicalJoint.rightWrist,
      AnatomicalJoint.rightWrist => AnatomicalJoint.leftWrist,
      _ => null,
    };
  }

  String _jointName(AnatomicalJoint joint) {
    return switch (joint) {
      AnatomicalJoint.neck => 'Neck',
      AnatomicalJoint.leftShoulder => 'Left Shoulder',
      AnatomicalJoint.rightShoulder => 'Right Shoulder',
      AnatomicalJoint.leftElbow => 'Left Elbow',
      AnatomicalJoint.rightElbow => 'Right Elbow',
      AnatomicalJoint.leftWrist => 'Left Wrist',
      AnatomicalJoint.rightWrist => 'Right Wrist',
      AnatomicalJoint.spine => 'Trunk / Spine',
      AnatomicalJoint.leftHip => 'Left Hip',
      AnatomicalJoint.rightHip => 'Right Hip',
      AnatomicalJoint.leftKnee => 'Left Knee',
      AnatomicalJoint.rightKnee => 'Right Knee',
      AnatomicalJoint.leftAnkle => 'Left Ankle',
      AnatomicalJoint.rightAnkle => 'Right Ankle',
    };
  }
}
