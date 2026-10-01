import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/models/exercise_analysis_config.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/services/human_presence_validator.dart';

void main() {
  const validator = HumanPresenceValidator();
  final config = ExerciseAnalysisConfig.squat;
  final requiredLandmarks = ['leftHip', 'rightHip', 'leftKnee', 'rightKnee', 'leftAnkle', 'rightAnkle'];

  test('rejects null or empty pose frame', () {
    final result = validator.validate(
      frame: null,
      requiredLandmarks: requiredLandmarks,
      config: config,
    );
    expect(result.isValidForAnalysis, isFalse);
    expect(result.status, HumanPresenceStatus.noHuman);
    expect(result.actionableCue, contains('not detected'));
  });

  test('rejects noise / objects with fewer than 6 valid landmarks', () {
    // E.g. A chair edge or backpack detected as 3 random points
    final noiseFrame = PoseFrame(
      timestamp: DateTime.now(),
      imageWidth: 640,
      imageHeight: 480,
      landmarks: const {
        'leftWrist': PoseLandmark(name: 'leftWrist', x: 200, y: 200, confidence: 0.8),
        'rightElbow': PoseLandmark(name: 'rightElbow', x: 220, y: 210, confidence: 0.75),
        'nose': PoseLandmark(name: 'nose', x: 210, y: 190, confidence: 0.85),
      },
    );

    final result = validator.validate(
      frame: noiseFrame,
      requiredLandmarks: requiredLandmarks,
      config: config,
    );

    expect(result.isValidForAnalysis, isFalse);
    expect(result.status, HumanPresenceStatus.noHuman);
    expect(result.actionableCue, contains('not detected'));
  });

  test('rejects hand-only detections even when many hand points are present', () {
    final handOnlyFrame = PoseFrame(
      timestamp: DateTime.now(),
      imageWidth: 640,
      imageHeight: 480,
      landmarks: const {
        'leftWrist': PoseLandmark(name: 'leftWrist', x: 200, y: 200, confidence: 0.9),
        'rightWrist': PoseLandmark(name: 'rightWrist', x: 240, y: 200, confidence: 0.9),
        'leftElbow': PoseLandmark(name: 'leftElbow', x: 195, y: 170, confidence: 0.9),
        'rightElbow': PoseLandmark(name: 'rightElbow', x: 245, y: 170, confidence: 0.9),
        'leftThumb': PoseLandmark(name: 'leftThumb', x: 190, y: 205, confidence: 0.9),
        'rightThumb': PoseLandmark(name: 'rightThumb', x: 250, y: 205, confidence: 0.9),
      },
    );

    final result = validator.validate(
      frame: handOnlyFrame,
      requiredLandmarks: const ['shoulder', 'elbow', 'wrist'],
      config: ExerciseAnalysisConfig.elbowFlexion,
    );

    expect(result.isValidForAnalysis, isFalse);
    expect(result.status, HumanPresenceStatus.noHuman);
    expect(result.actionableCue, contains('torso'));
  });

  test('accepts an isolated arm exercise without requiring legs in frame', () {
    final upperBodyFrame = PoseFrame(
      timestamp: DateTime.now(),
      imageWidth: 640,
      imageHeight: 480,
      landmarks: const {
        'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 280, y: 150, confidence: 0.9),
        'leftElbow': PoseLandmark(name: 'leftElbow', x: 250, y: 210, confidence: 0.9),
        'leftWrist': PoseLandmark(name: 'leftWrist', x: 230, y: 270, confidence: 0.9),
      },
    );

    final result = validator.validate(
      frame: upperBodyFrame,
      requiredLandmarks: ExerciseAnalysisConfig.elbowFlexion.requiredLandmarks,
      config: ExerciseAnalysisConfig.elbowFlexion,
    );

    expect(result.isValidForAnalysis, isTrue);
  });

  test('full-body squat validation rejects a cropped head', () {
    final frame = PoseFrame(
      timestamp: DateTime.now(),
      imageWidth: 640,
      imageHeight: 480,
      landmarks: const {
        'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 280, y: 100, confidence: 0.9),
        'leftHip': PoseLandmark(name: 'leftHip', x: 290, y: 200, confidence: 0.9),
        'leftKnee': PoseLandmark(name: 'leftKnee', x: 290, y: 300, confidence: 0.9),
        'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 290, y: 400, confidence: 0.9),
        'leftElbow': PoseLandmark(name: 'leftElbow', x: 250, y: 150, confidence: 0.9),
        'leftWrist': PoseLandmark(name: 'leftWrist', x: 230, y: 190, confidence: 0.9),
      },
    );

    final result = validator.validate(
      frame: frame,
      requiredLandmarks: ExerciseAnalysisConfig.squat.requiredLandmarks,
      config: ExerciseAnalysisConfig.squat,
    );

    expect(result.isValidForAnalysis, isFalse);
    expect(result.missingRequiredLandmarks, contains('head'));
  });

  test('rejects landmarks with low confidence (shadows/reflections)', () {
    final lowConfFrame = PoseFrame(
      timestamp: DateTime.now(),
      imageWidth: 640,
      imageHeight: 480,
      landmarks: const {
        'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 280, y: 120, confidence: 0.2),
        'rightShoulder': PoseLandmark(name: 'rightShoulder', x: 360, y: 120, confidence: 0.25),
        'leftHip': PoseLandmark(name: 'leftHip', x: 290, y: 240, confidence: 0.3),
        'rightHip': PoseLandmark(name: 'rightHip', x: 350, y: 240, confidence: 0.2),
        'leftKnee': PoseLandmark(name: 'leftKnee', x: 295, y: 340, confidence: 0.15),
        'rightKnee': PoseLandmark(name: 'rightKnee', x: 345, y: 340, confidence: 0.2),
        'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 300, y: 440, confidence: 0.1),
        'rightAnkle': PoseLandmark(name: 'rightAnkle', x: 340, y: 440, confidence: 0.1),
      },
    );

    final result = validator.validate(
      frame: lowConfFrame,
      requiredLandmarks: requiredLandmarks,
      config: config,
    );

    expect(result.isValidForAnalysis, isFalse);
    expect(result.status, HumanPresenceStatus.noHuman);
  });

  test('rejects partial body when exercise-required joints are off-screen', () {
    // Only upper body visible; ankles and knees are off-screen for a squat
    final upperBodyFrame = PoseFrame(
      timestamp: DateTime.now(),
      imageWidth: 640,
      imageHeight: 480,
      landmarks: const {
        'nose': PoseLandmark(name: 'nose', x: 320, y: 60, confidence: 0.9),
        'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 280, y: 120, confidence: 0.9),
        'rightShoulder': PoseLandmark(name: 'rightShoulder', x: 360, y: 120, confidence: 0.9),
        'leftElbow': PoseLandmark(name: 'leftElbow', x: 250, y: 180, confidence: 0.9),
        'rightElbow': PoseLandmark(name: 'rightElbow', x: 390, y: 180, confidence: 0.9),
        'leftWrist': PoseLandmark(name: 'leftWrist', x: 240, y: 240, confidence: 0.9),
        'rightWrist': PoseLandmark(name: 'rightWrist', x: 400, y: 240, confidence: 0.9),
        'leftHip': PoseLandmark(name: 'leftHip', x: 290, y: 240, confidence: 0.9),
        'rightHip': PoseLandmark(name: 'rightHip', x: 350, y: 240, confidence: 0.9),
      },
    );

    final result = validator.validate(
      frame: upperBodyFrame,
      requiredLandmarks: requiredLandmarks,
      config: config,
    );

    expect(result.isValidForAnalysis, isFalse);
    expect(result.status, HumanPresenceStatus.insufficientForExercise);
    expect(result.missingRequiredLandmarks, isNotEmpty);
  });

  test('validates full human body with all required landmarks present', () {
    final validFullBodyFrame = PoseFrame(
      timestamp: DateTime.now(),
      imageWidth: 640,
      imageHeight: 480,
      landmarks: const {
        'nose': PoseLandmark(name: 'nose', x: 320, y: 60, confidence: 0.95),
        'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 280, y: 120, confidence: 0.95),
        'rightShoulder': PoseLandmark(name: 'rightShoulder', x: 360, y: 120, confidence: 0.95),
        'leftHip': PoseLandmark(name: 'leftHip', x: 290, y: 240, confidence: 0.95),
        'rightHip': PoseLandmark(name: 'rightHip', x: 350, y: 240, confidence: 0.95),
        'leftKnee': PoseLandmark(name: 'leftKnee', x: 295, y: 340, confidence: 0.95),
        'rightKnee': PoseLandmark(name: 'rightKnee', x: 345, y: 340, confidence: 0.95),
        'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 300, y: 440, confidence: 0.95),
        'rightAnkle': PoseLandmark(name: 'rightAnkle', x: 340, y: 440, confidence: 0.95),
      },
    );

    final result = validator.validate(
      frame: validFullBodyFrame,
      requiredLandmarks: requiredLandmarks,
      config: config,
    );

    expect(result.isValidForAnalysis, isTrue);
    expect(result.status, HumanPresenceStatus.validHuman);
    expect(result.averageConfidence, greaterThanOrEqualTo(0.9));
  });
}
