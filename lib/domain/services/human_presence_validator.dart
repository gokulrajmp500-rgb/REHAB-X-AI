import 'dart:math' as math;
import '../models/exercise_analysis_config.dart';
import '../models/pose_models.dart';

enum HumanPresenceStatus {
  validHuman,
  partialBody,
  insufficientForExercise,
  offScreen,
  multiplePeople,
  noHuman,
  lowConfidence,
}

class HumanValidationResult {
  const HumanValidationResult({
    required this.status,
    required this.isValidForAnalysis,
    required this.completenessScore,
    required this.averageConfidence,
    required this.actionableCue,
    this.missingRequiredLandmarks = const [],
    this.bodyBoundingBox,
    this.isClippedAtBoundary = false,
  });

  final HumanPresenceStatus status;
  final bool isValidForAnalysis;
  final double completenessScore;
  final double averageConfidence;
  final String actionableCue;
  final List<String> missingRequiredLandmarks;
  final BoundingBox2D? bodyBoundingBox;
  final bool isClippedAtBoundary;

  String get statusDisplayString => switch (status) {
    HumanPresenceStatus.validHuman => 'HUMAN DETECTED',
    HumanPresenceStatus.partialBody => 'PARTIAL BODY DETECTED',
    HumanPresenceStatus.insufficientForExercise => 'REQUIRED JOINTS NOT VISIBLE',
    HumanPresenceStatus.offScreen => 'BODY OUTSIDE CAMERA FRAME',
    HumanPresenceStatus.multiplePeople => 'MULTIPLE PEOPLE DETECTED',
    HumanPresenceStatus.noHuman => 'NO HUMAN DETECTED',
    HumanPresenceStatus.lowConfidence => 'POOR VISIBILITY / LOW LIGHT',
  };
}

class BoundingBox2D {
  const BoundingBox2D({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.width,
    required this.height,
    required this.areaRatio,
    required this.aspectRatio,
  });

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double width;
  final double height;
  final double areaRatio;
  final double aspectRatio; // height / width
}

/// Dedicated validation layer that distinguishes genuine human bodies from
/// inanimate objects, furniture, shadows, walls, and incomplete/off-screen bodies.
class HumanPresenceValidator {
  const HumanPresenceValidator({
    this.minConfidenceThreshold = 0.50,
    this.minLandmarkCount = 6,
    this.minBodyHeightRatio = 0.20,
    this.maxBodyHeightRatio = 0.95,
  });

  final double minConfidenceThreshold;
  final int minLandmarkCount;
  final double minBodyHeightRatio;
  final double maxBodyHeightRatio;

  /// Comprehensive multi-check evaluation of human presence and body completeness.
  HumanValidationResult validate({
    required PoseFrame? frame,
    required List<String> requiredLandmarks,
    ExerciseAnalysisConfig? config,
  }) {
    if (frame == null || frame.landmarks.isEmpty) {
      return const HumanValidationResult(
        status: HumanPresenceStatus.noHuman,
        isValidForAnalysis: false,
        completenessScore: 0.0,
        averageConfidence: 0.0,
        actionableCue: 'Human body not detected. Step into the camera frame.',
      );
    }

    // 1. Multiple Person Gate
    if (frame.isMultiPerson || frame.personCount > 1) {
      return const HumanValidationResult(
        status: HumanPresenceStatus.multiplePeople,
        isValidForAnalysis: false,
        completenessScore: 0.0,
        averageConfidence: 0.0,
        actionableCue: 'Multiple people detected. Keep only one person in frame.',
      );
    }

    final landmarks = frame.landmarks;
    final validLandmarks = landmarks.values.where((l) => l.isValid && l.confidence >= minConfidenceThreshold).toList();
    final minimumPoints = config != null && !config.requiresFullBody
      ? math.max(3, requiredLandmarks.length)
      : minLandmarkCount;

    // 2. Require enough points for either the full body or the exercise joint chain.
    if (validLandmarks.length < minimumPoints) {
      return HumanValidationResult(
        status: HumanPresenceStatus.noHuman,
        isValidForAnalysis: false,
        completenessScore: validLandmarks.length / 25.0,
        averageConfidence: _calcAvgConfidence(validLandmarks),
        actionableCue: 'Human body not detected. Ensure your body is well-lit and facing the camera.',
      );
    }

    // 3. Anatomical Distribution Check
    // Genuine human pose must contain at least torso landmarks (shoulders or hips)
    final hasShoulders = (landmarks['leftShoulder']?.isValid == true && landmarks['leftShoulder']!.confidence >= minConfidenceThreshold) ||
        (landmarks['rightShoulder']?.isValid == true && landmarks['rightShoulder']!.confidence >= minConfidenceThreshold);
    final hasHips = (landmarks['leftHip']?.isValid == true && landmarks['leftHip']!.confidence >= minConfidenceThreshold) ||
        (landmarks['rightHip']?.isValid == true && landmarks['rightHip']!.confidence >= minConfidenceThreshold);
    if (!hasShoulders && !hasHips) {
      // Inanimate objects might produce isolated limb points without a torso
      return HumanValidationResult(
        status: HumanPresenceStatus.noHuman,
        isValidForAnalysis: false,
        completenessScore: 0.1,
        averageConfidence: _calcAvgConfidence(validLandmarks),
        actionableCue: 'Human torso not detected. Step fully into camera view.',
      );
    }

    // 4. Calculate Bounding Box & Frame Coverage
    final imgWidth = (frame.imageWidth ?? 640).toDouble();
    final imgHeight = (frame.imageHeight ?? 480).toDouble();

    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final l in validLandmarks) {
      minX = math.min(minX, l.x);
      maxX = math.max(maxX, l.x);
      minY = math.min(minY, l.y);
      maxY = math.max(maxY, l.y);
    }

    final bWidth = math.max(maxX - minX, 1.0);
    final bHeight = math.max(maxY - minY, 1.0);
    final areaRatio = (bWidth * bHeight) / (imgWidth * imgHeight);
    final aspectRatio = bHeight / bWidth;

    final bbox = BoundingBox2D(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      width: bWidth,
      height: bHeight,
      areaRatio: areaRatio,
      aspectRatio: aspectRatio,
    );

    // 5. Check Anthropometric Proportions & Size
    final heightRatio = bHeight / imgHeight;
    if (heightRatio < minBodyHeightRatio) {
      return HumanValidationResult(
        status: HumanPresenceStatus.lowConfidence,
        isValidForAnalysis: false,
        completenessScore: heightRatio,
        averageConfidence: _calcAvgConfidence(validLandmarks),
        bodyBoundingBox: bbox,
        actionableCue: 'Move closer to the camera — body is too small for accurate tracking.',
      );
    }

    // 6. Check Boundary Clipping on Required Joints
    bool isClipped = false;
    final marginX = imgWidth * 0.02;
    final marginY = imgHeight * 0.02;

    for (final req in requiredLandmarks) {
      final lm = landmarks[req];
      if (lm != null && lm.isValid) {
        if (lm.x <= marginX || lm.x >= (imgWidth - marginX) || lm.y <= marginY || lm.y >= (imgHeight - marginY)) {
          isClipped = true;
          break;
        }
      }
    }

    // 7. Exercise-Specific Required Landmarks Verification
    final missingLandmarks = <String>[];
    for (final req in requiredLandmarks) {
      if (!_hasAny(landmarks, [req])) missingLandmarks.add(req);
    }

    if (config?.requiresFullBody == true) {
      if (!_hasAny(landmarks, const ['nose', 'leftEye', 'rightEye', 'leftEar', 'rightEar'])) {
        missingLandmarks.add('head');
      }
      for (final group in const ['shoulder', 'hip', 'knee', 'ankle']) {
        if (!_hasAny(landmarks, [group])) missingLandmarks.add(group);
      }
    }

    final avgConf = _calcAvgConfidence(validLandmarks);
    final completenessScore = (validLandmarks.length / 25.0).clamp(0.0, 1.0);

    if (isClipped) {
      return HumanValidationResult(
        status: HumanPresenceStatus.offScreen,
        isValidForAnalysis: false,
        completenessScore: completenessScore,
        averageConfidence: avgConf,
        missingRequiredLandmarks: missingLandmarks,
        bodyBoundingBox: bbox,
        isClippedAtBoundary: true,
        actionableCue: 'Step back — part of your body is touching the camera edge.',
      );
    }

    if (missingLandmarks.isNotEmpty) {
      final cue = _buildMissingJointCue(missingLandmarks);
      return HumanValidationResult(
        status: HumanPresenceStatus.insufficientForExercise,
        isValidForAnalysis: false,
        completenessScore: completenessScore,
        averageConfidence: avgConf,
        missingRequiredLandmarks: missingLandmarks,
        bodyBoundingBox: bbox,
        actionableCue: cue,
      );
    }

    if (avgConf < minConfidenceThreshold) {
      return HumanValidationResult(
        status: HumanPresenceStatus.lowConfidence,
        isValidForAnalysis: false,
        completenessScore: completenessScore,
        averageConfidence: avgConf,
        bodyBoundingBox: bbox,
        actionableCue: 'Improve lighting and contrast for reliable joint tracking.',
      );
    }

    final hasHead = _hasAny(landmarks, const [
      'nose', 'leftEye', 'rightEye', 'leftEar', 'rightEar',
    ]);
    final isFullBody = hasHead && hasShoulders && hasHips &&
        (landmarks['leftKnee']?.isValid == true || landmarks['rightKnee']?.isValid == true) &&
        (landmarks['leftAnkle']?.isValid == true || landmarks['rightAnkle']?.isValid == true);

    return HumanValidationResult(
      status: HumanPresenceStatus.validHuman,
      isValidForAnalysis: true,
      completenessScore: isFullBody ? 1.0 : completenessScore,
      averageConfidence: avgConf,
      bodyBoundingBox: bbox,
      actionableCue: 'Optimal human tracking active. You may perform your movement.',
    );
  }

  double _calcAvgConfidence(List<PoseLandmark> landmarks) {
    if (landmarks.isEmpty) return 0.0;
    return landmarks.map((l) => l.confidence).reduce((a, b) => a + b) / landmarks.length;
  }

  String _buildMissingJointCue(List<String> missing) {
    if (missing.contains('head')) {
      return 'Head is outside the frame. Step back until your full body is visible.';
    }
    if (missing.contains('ankle')) {
      return 'Lower body incomplete: step back so ankles and feet are inside the frame.';
    }
    if (missing.contains('knee') || missing.contains('hip')) {
      return 'Hips and knees not fully visible: ensure your lower body is in frame.';
    }
    if (missing.contains('wrist') || missing.contains('elbow')) {
      return 'Arms out of frame: step back so your upper limbs are completely visible.';
    }
    if (missing.contains('shoulder')) {
      return 'Shoulders not clearly detected: face the camera squarely.';
    }
    return 'Required joints (${missing.join(", ")}) not visible in frame.';
  }

  bool _hasAny(Map<String, PoseLandmark> landmarks, List<String> names) {
    for (final name in names) {
      final direct = landmarks[name];
      if (direct?.isValid == true && direct!.confidence >= minConfidenceThreshold) {
        return true;
      }
      final candidates = switch (name) {
        'hip' || 'knee' || 'ankle' || 'shoulder' || 'elbow' || 'wrist' => [
          'left${_capitalize(name)}',
          'right${_capitalize(name)}',
        ],
        'foot' => const [
          'leftFootIndex', 'rightFootIndex', 'leftHeel', 'rightHeel',
        ],
        _ => const <String>[],
      };
      if (candidates.any((candidate) {
        final landmark = landmarks[candidate];
        return landmark?.isValid == true &&
            landmark!.confidence >= minConfidenceThreshold;
      })) {
        return true;
      }
    }
    return false;
  }

  String _capitalize(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}
