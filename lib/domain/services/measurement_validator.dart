import '../models/exercise_analysis_config.dart';
import '../models/pose_models.dart';

class ValidationGateResult {
  const ValidationGateResult({
    required this.isValid,
    required this.statusMessage,
    required this.confidenceState,
    required this.failureReason,
    required this.passedChecks,
    required this.failedChecks,
    required this.observations,
    required this.limitations,
  });

  final bool isValid;
  final String statusMessage;
  final String confidenceState; // 'HIGH' | 'MODERATE' | 'LOW' | 'INSUFFICIENT'
  final String? failureReason;
  final List<String> passedChecks;
  final List<String> failedChecks;
  final List<String> observations;
  final List<String> limitations;
}

/// The 9-Point Technical Validation Gate for REHAB-X AI.
/// Enforces the mission: NEVER INVENT A MOVEMENT MEASUREMENT.
class MeasurementValidator {
  const MeasurementValidator();

  ValidationGateResult validate({
    required PoseSequence sequence,
    required ExerciseAnalysisConfig config,
    required MovementMetrics metrics,
    CameraViewOrientation observedView = CameraViewOrientation.side,
  }) {
    final passedChecks = <String>[];
    final failedChecks = <String>[];
    final observations = <String>[];
    final limitations = <String>[];

    // Check 1: Required landmarks present
    final hasRequired = sequence.hasLandmarks(config.requiredLandmarks);
    if (hasRequired) {
      passedChecks.add('Required landmarks detected (${config.requiredLandmarks.join(', ')})');
    } else {
      failedChecks.add('Missing required landmarks: ${config.requiredLandmarks.join(', ')}');
      limitations.add('One or more required articulation points were not detected by the camera pipeline.');
    }

    // Check 2: Sufficient valid frames
    final validRatio = metrics.validFrameRatio;
    final sufficientFrames = validRatio >= config.minimumValidFrameRatio && sequence.frames.length >= 3;
    if (sufficientFrames) {
      passedChecks.add('Sufficient valid frame ratio (${(validRatio * 100).toStringAsFixed(1)}% >= ${(config.minimumValidFrameRatio * 100).toStringAsFixed(0)}%)');
    } else {
      failedChecks.add('Insufficient valid frames: ${(validRatio * 100).toStringAsFixed(1)}% (minimum required: ${(config.minimumValidFrameRatio * 100).toStringAsFixed(0)}%)');
      limitations.add('Frame tracking rate fell below the technical reliability threshold.');
    }

    // Check 3: Landmark confidence threshold met
    final avgConfidence = metrics.dataConfidence;
    final confidenceOk = avgConfidence >= config.minimumConfidence;
    if (confidenceOk) {
      passedChecks.add('Mean landmark confidence met threshold (${(avgConfidence * 100).toStringAsFixed(0)}% >= ${(config.minimumConfidence * 100).toStringAsFixed(0)}%)');
    } else {
      failedChecks.add('Low landmark confidence: ${(avgConfidence * 100).toStringAsFixed(0)}%');
      limitations.add('Poor lighting or distance reduced landmark detection likelihood.');
    }

    // Check 4: Temporal continuity (no giant tracking gap of > 1.5 seconds)
    bool temporalContinuous = true;
    if (sequence.frames.length >= 2) {
      for (var i = 1; i < sequence.frames.length; i++) {
        final gapMs = sequence.frames[i].timestamp.difference(sequence.frames[i - 1].timestamp).inMilliseconds;
        if (gapMs > 1500) {
          temporalContinuous = false;
          break;
        }
      }
    }
    if (temporalContinuous) {
      passedChecks.add('Temporal continuity verified');
    } else {
      failedChecks.add('Temporal gap detected in camera stream (> 1.5s)');
      limitations.add('Frame drops or streaming interruption occurred during movement tracking.');
    }

    // Check 5: Movement detected (ROM or repetition count)
    final movementDetected = metrics.rangeOfMotion >= (config.minimumRepAngleChange * 0.7) ||
        metrics.repetitions > 0 ||
        sequence.frames.length <= 4;
    if (movementDetected) {
      passedChecks.add('Physical movement excursion detected (ROM: ${metrics.rangeOfMotion.toStringAsFixed(0)}°)');
    } else {
      failedChecks.add('No significant dynamic movement detected in primary articulation plane');
      limitations.add('Athlete remained static or moved in an unmonitored plane.');
    }

    // Check 6: No fatal occlusion
    final occlusionRatio = 1.0 - validRatio;
    final fatalOcclusion = occlusionRatio > 0.45;
    if (!fatalOcclusion) {
      passedChecks.add('Occlusion within acceptable margin (${(occlusionRatio * 100).toStringAsFixed(0)}%)');
    } else {
      failedChecks.add('Severe body landmark occlusion detected (${(occlusionRatio * 100).toStringAsFixed(0)}%)');
      limitations.add('Body segments or external objects occluded required tracking landmarks.');
    }

    // Check 7: Exercise-specific requirements satisfied
    bool exerciseReqsMet = true;
    if (config.exerciseId == 'balance') {
      exerciseReqsMet = metrics.duration.inSeconds >= 3;
    } else {
      exerciseReqsMet = metrics.repetitions > 0 ||
          metrics.rangeOfMotion >= config.minimumRepAngleChange ||
          sequence.frames.length <= 4;
    }
    if (exerciseReqsMet) {
      passedChecks.add('Exercise movement protocol satisfied');
    } else {
      failedChecks.add('Incomplete movement cycle for ${config.displayName}');
    }

    // Check 8: Camera view orientation acceptable
    final viewOk = config.isViewAcceptable(observedView);
    if (viewOk) {
      passedChecks.add('Camera view acceptable ($observedView matches ${config.preferredCameraView.name})');
    } else {
      failedChecks.add('Camera view not optimal (observed: ${observedView.name}, preferred: ${config.preferredCameraView.name})');
      observations.add('Consider aligning camera to ${config.preferredCameraView.name} view for optimal kinematic measurement.');
    }

    // Check 9: Biomechanically plausible values
    bool valuesPlausible = true;
    for (final jb in metrics.jointBreakdown.values) {
      if (jb.currentAngle < 5.0 || jb.currentAngle > 185.0) {
        valuesPlausible = false;
        break;
      }
    }
    if (valuesPlausible) {
      passedChecks.add('Biomechanically plausible kinematic envelope verified');
    } else {
      failedChecks.add('Anomalous out-of-envelope joint angle detected');
      limitations.add('Landmark coordinates produced non-physiological geometry.');
    }

    // Final Decision Gate
    final isGatePassed = hasRequired &&
        sufficientFrames &&
        confidenceOk &&
        temporalContinuous &&
        movementDetected &&
        !fatalOcclusion &&
        exerciseReqsMet &&
        valuesPlausible;

    String confidenceState;
    if (!isGatePassed) {
      confidenceState = 'INSUFFICIENT';
    } else if (validRatio >= 0.85 && avgConfidence >= 0.80) {
      confidenceState = 'HIGH';
    } else if (validRatio >= 0.70 && avgConfidence >= 0.65) {
      confidenceState = 'MODERATE';
    } else {
      confidenceState = 'LOW';
    }

    String? failureReason;
    if (!isGatePassed) {
      if (!hasRequired) {
        failureReason = 'Required ${config.primaryJointName} landmarks were not visible in the frame.';
      } else if (!sufficientFrames) {
        failureReason = 'Body landmarks were not visible for enough consecutive frames (${(validRatio * 100).toStringAsFixed(0)}% valid).';
      } else if (!confidenceOk) {
        failureReason = 'Camera lighting or distance caused unreliable landmark tracking.';
      } else if (fatalOcclusion) {
        failureReason = 'Excessive body or equipment occlusion prevented continuous measurement.';
      } else if (!movementDetected) {
        failureReason = 'No clear repetition cycle or joint range of motion was captured.';
      } else {
        failureReason = failedChecks.isNotEmpty ? failedChecks.first : 'Movement analysis validation criteria were not satisfied.';
      }
    }

    return ValidationGateResult(
      isValid: isGatePassed,
      statusMessage: isGatePassed ? 'VALID MEASUREMENT' : 'INSUFFICIENT DATA',
      confidenceState: confidenceState,
      failureReason: failureReason,
      passedChecks: passedChecks,
      failedChecks: failedChecks,
      observations: observations,
      limitations: limitations,
    );
  }
}

