import 'dart:math' as math;

import '../models/exercise_analysis_config.dart';
import '../models/pose_models.dart';

enum FramingState { tooClose, tooFar, optimal, incomplete }

class LandmarkVisibilityChecklist {
  const LandmarkVisibilityChecklist({
    required this.hasHead,
    required this.hasShoulders,
    required this.hasHips,
    required this.hasKnees,
    required this.hasAnkles,
    this.hasFeet = false,
  });

  final bool hasHead;
  final bool hasShoulders;
  final bool hasHips;
  final bool hasKnees;
  final bool hasAnkles;
  final bool hasFeet;

  bool get isFullBodyVisible =>
      hasHead && hasShoulders && hasHips && hasKnees && hasAnkles;

  int get visibleCount =>
      (hasHead ? 1 : 0) +
      (hasShoulders ? 1 : 0) +
      (hasHips ? 1 : 0) +
      (hasKnees ? 1 : 0) +
      (hasAnkles ? 1 : 0) +
      (hasFeet ? 1 : 0);
}

class CameraReadinessEvaluation {
  const CameraReadinessEvaluation({
    required this.isReady,
    required this.checklist,
    required this.statusMessage,
    required this.confidence,
    required this.guidanceCue,
    this.lightingAdequate = true,
    this.distanceAdequate = true,
    this.framing = FramingState.incomplete,
    this.isMultiPerson = false,
    this.viewSuggestion,
  });

  final bool isReady;
  final LandmarkVisibilityChecklist checklist;
  final String statusMessage;
  final double confidence;
  final String guidanceCue;
  final bool lightingAdequate;
  final bool distanceAdequate;
  final FramingState framing;
  final bool isMultiPerson;
  final String? viewSuggestion;
}

class CameraReadinessService {
  const CameraReadinessService();

  CameraReadinessEvaluation evaluateFrame(
    PoseFrame? frame, {
    List<String>? requiredLandmarks,
    ExerciseAnalysisConfig? config,
  }) {
    if (frame == null) {
      return const CameraReadinessEvaluation(
        isReady: false,
        checklist: LandmarkVisibilityChecklist(
          hasHead: false,
          hasShoulders: false,
          hasHips: false,
          hasKnees: false,
          hasAnkles: false,
          hasFeet: false,
        ),
        statusMessage: 'ADJUST CAMERA',
        confidence: 0,
        guidanceCue: 'Step into camera frame to begin positioning.',
        lightingAdequate: false,
        distanceAdequate: false,
        framing: FramingState.incomplete,
      );
    }

    // Check Multi-Person protection
    if (frame.isMultiPerson || frame.personCount > 1) {
      return CameraReadinessEvaluation(
        isReady: false,
        checklist: const LandmarkVisibilityChecklist(
          hasHead: false,
          hasShoulders: false,
          hasHips: false,
          hasKnees: false,
          hasAnkles: false,
        ),
        statusMessage: 'ADJUST CAMERA',
        confidence: 0,
        guidanceCue: 'Multiple people detected. Keep only one person in the camera frame.',
        lightingAdequate: true,
        distanceAdequate: false,
        framing: FramingState.incomplete,
        isMultiPerson: true,
      );
    }

    final lm = frame.landmarks;
    final hasHead = (lm['nose']?.isValid ?? false) ||
        (lm['leftEye']?.isValid ?? false) ||
        (lm['rightEye']?.isValid ?? false);
    final hasShoulders = (lm['leftShoulder']?.isValid ?? false) ||
        (lm['rightShoulder']?.isValid ?? false) ||
        (lm['shoulder']?.isValid ?? false);
    final hasHips = (lm['leftHip']?.isValid ?? false) ||
        (lm['rightHip']?.isValid ?? false) ||
        (lm['hip']?.isValid ?? false);
    final hasKnees = (lm['leftKnee']?.isValid ?? false) ||
        (lm['rightKnee']?.isValid ?? false) ||
        (lm['knee']?.isValid ?? false);
    final hasAnkles = (lm['leftAnkle']?.isValid ?? false) ||
        (lm['rightAnkle']?.isValid ?? false) ||
        (lm['ankle']?.isValid ?? false);
    final hasFeet = (lm['leftFootIndex']?.isValid ?? false) ||
        (lm['rightFootIndex']?.isValid ?? false) ||
        (lm['leftHeel']?.isValid ?? false) ||
        (lm['rightHeel']?.isValid ?? false) ||
        hasAnkles;

    final checklist = LandmarkVisibilityChecklist(
      hasHead: hasHead,
      hasShoulders: hasShoulders,
      hasHips: hasHips,
      hasKnees: hasKnees,
      hasAnkles: hasAnkles,
      hasFeet: hasFeet,
    );
    final expectedLandmarks =
      requiredLandmarks ?? config?.requiredLandmarks ?? const <String>[];
    final requiresFullBody = config?.requiresFullBody ?? expectedLandmarks.isEmpty;
    final missingRequired = expectedLandmarks
      .where((name) => _findLandmark(lm, name) == null)
      .toList();

    // Calculate average confidence of detected landmarks
    final validLms = lm.values.where((l) => l.isValid).toList();
    final avgConfidence = validLms.isEmpty
        ? 0.0
        : validLms.map((l) => l.confidence).reduce((a, b) => a + b) / validLms.length;

    // Check boundary clipping and bounding box framing (Requirement 5)
    final width = (frame.imageWidth ?? 640).toDouble();
    final height = (frame.imageHeight ?? 480).toDouble();

    bool clipping = false;
    double minY = double.infinity;
    double maxY = -double.infinity;
    final framingNames = <String>{...expectedLandmarks};
    if (requiresFullBody) {
      framingNames.addAll(const [
        'nose', 'leftEye', 'rightEye', 'leftEar', 'rightEar',
        'leftShoulder', 'rightShoulder', 'leftHip', 'rightHip',
        'leftKnee', 'rightKnee', 'leftAnkle', 'rightAnkle',
      ]);
    }
    final framingLandmarks = framingNames.isEmpty
        ? validLms
        : framingNames
              .map((name) => _findLandmark(lm, name))
              .whereType<PoseLandmark>()
              .toList();

    for (final l in framingLandmarks) {
      if (l.x < width * 0.03 || l.x > width * 0.97 || l.y < height * 0.03 || l.y > height * 0.97) {
        clipping = true;
      }
      minY = math.min(minY, l.y);
      maxY = math.max(maxY, l.y);
    }

    final bodyHeight = framingLandmarks.isNotEmpty ? (maxY - minY) : 0.0;
    final heightRatio = height > 0 ? (bodyHeight / height) : 0.0;

    FramingState framing = FramingState.incomplete;
    if (framingLandmarks.isNotEmpty) {
      if (heightRatio > 0.86 || clipping) {
        framing = FramingState.tooClose;
      } else if (heightRatio < (requiresFullBody ? 0.35 : 0.16)) {
        framing = FramingState.tooFar;
      } else {
        framing = FramingState.optimal;
      }
    }

    // Camera view check: Side vs Front estimation (Requirement 7)
    String? viewSuggestion;
    if (config != null && framingLandmarks.isNotEmpty) {
      final leftShoulder = lm['leftShoulder'];
      final rightShoulder = lm['rightShoulder'];
      if (leftShoulder != null && rightShoulder != null && leftShoulder.isValid && rightShoulder.isValid) {
        final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
        final shoulderRatio = bodyHeight > 0 ? (shoulderWidth / bodyHeight) : 0.0;
        final isFrontFacing = shoulderRatio > 0.16;

        if (config.preferredCameraView == CameraViewOrientation.side && isFrontFacing) {
          viewSuggestion = 'Rotate camera or body to side view for more reliable ${config.primaryJointName.toLowerCase()} movement analysis.';
        } else if (config.preferredCameraView == CameraViewOrientation.front && !isFrontFacing) {
          viewSuggestion = 'Rotate camera to front view for symmetrical body tracking.';
        }
      }
    }

    String cue;
    String status = 'ADJUST CAMERA';
    bool ready = false;

    if (requiresFullBody && !checklist.hasHead && checklist.hasKnees) {
      cue = 'Camera tilted too low or move farther back.';
    } else if (requiresFullBody && !checklist.hasAnkles && checklist.hasHead) {
      cue = 'Move farther back — ankles and feet are out of frame.';
    } else if (framing == FramingState.tooClose) {
      cue = 'Move camera farther away — full body needs more space.';
    } else if (framing == FramingState.tooFar) {
      cue = 'Move camera closer — body is too small in the frame.';
    } else if (clipping) {
      cue = 'Move farther back — body is near the frame edge.';
    } else if (avgConfidence < 0.55) {
      cue = 'Improve lighting — landmarks have low confidence.';
    } else if (requiresFullBody && !checklist.isFullBodyVisible) {
      cue = 'Full body not detected. Ensure head to feet are visible.';
    } else if (missingRequired.isNotEmpty) {
      cue = 'Required ${config?.displayName ?? 'movement'} joints not visible: ${missingRequired.join(', ')}.';
    } else if (viewSuggestion != null) {
      cue = viewSuggestion;
      // If view is acceptable even if not preferred, allow starting, else guide user
      if (config != null && config.acceptableCameraViews.isNotEmpty) {
        status = 'CAMERA READY (ACCEPTABLE VIEW)';
        ready = true;
      } else {
        status = 'ADJUST CAMERA VIEW';
      }
    } else {
      status = 'CAMERA READY';
      cue = requiresFullBody
          ? 'Optimal positioning detected. You may begin.'
          : 'Required movement joints are visible. You may begin.';
      ready = true;
    }

    return CameraReadinessEvaluation(
      isReady: ready,
      checklist: checklist,
      statusMessage: status,
      confidence: avgConfidence,
      guidanceCue: cue,
      lightingAdequate: avgConfidence >= 0.55,
      distanceAdequate: framing == FramingState.optimal,
      framing: framing,
      isMultiPerson: false,
      viewSuggestion: viewSuggestion,
    );
  }

  PoseLandmark? _findLandmark(Map<String, PoseLandmark> landmarks, String name) {
    final direct = landmarks[name];
    if (direct?.isValid == true) return direct;
    final baseName = switch (name) {
      'hip' || 'knee' || 'ankle' || 'shoulder' || 'elbow' || 'wrist' => name,
      'foot' => 'FootIndex',
      _ => null,
    };
    if (baseName == null) return null;
    final candidates = baseName == 'FootIndex'
        ? const ['leftFootIndex', 'rightFootIndex', 'leftHeel', 'rightHeel']
        : ['left${_capitalize(baseName)}', 'right${_capitalize(baseName)}'];
    for (final candidate in candidates) {
      final landmark = landmarks[candidate];
      if (landmark?.isValid == true) return landmark;
    }
    return null;
  }

  String _capitalize(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}
