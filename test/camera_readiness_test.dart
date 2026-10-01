import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/models/exercise_analysis_config.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/services/camera_readiness_service.dart';

void main() {
  group('CameraReadinessService', () {
    const service = CameraReadinessService();

    test('null frame evaluates to not ready and prompts step into frame', () {
      final eval = service.evaluateFrame(null);
      expect(eval.isReady, isFalse);
      expect(eval.statusMessage, 'ADJUST CAMERA');
      expect(eval.checklist.isFullBodyVisible, isFalse);
      expect(eval.guidanceCue, contains('Step into camera'));
    });

    test('frame missing ankles instructs to move farther back', () {
      final frame = PoseFrame(
        timestamp: DateTime.now(),
        imageWidth: 640,
        imageHeight: 480,
        landmarks: const {
          'nose': PoseLandmark(name: 'nose', x: 320, y: 80),
          'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 280, y: 150),
          'rightShoulder': PoseLandmark(name: 'rightShoulder', x: 360, y: 150),
          'leftHip': PoseLandmark(name: 'leftHip', x: 290, y: 280),
          'rightHip': PoseLandmark(name: 'rightHip', x: 350, y: 280),
          'leftKnee': PoseLandmark(name: 'leftKnee', x: 290, y: 400),
          'rightKnee': PoseLandmark(name: 'rightKnee', x: 350, y: 400),
        },
      );

      final eval = service.evaluateFrame(frame);
      expect(eval.isReady, isFalse);
      expect(eval.checklist.hasHead, isTrue);
      expect(eval.checklist.hasAnkles, isFalse);
      expect(eval.guidanceCue, contains('Move farther back'));
    });

    test('frame with all key landmarks and adequate margins evaluates to ready', () {
      final frame = PoseFrame(
        timestamp: DateTime.now(),
        imageWidth: 640,
        imageHeight: 480,
        landmarks: const {
          'nose': PoseLandmark(name: 'nose', x: 320, y: 60),
          'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 280, y: 120),
          'rightShoulder': PoseLandmark(name: 'rightShoulder', x: 360, y: 120),
          'leftHip': PoseLandmark(name: 'leftHip', x: 290, y: 220),
          'rightHip': PoseLandmark(name: 'rightHip', x: 350, y: 220),
          'leftKnee': PoseLandmark(name: 'leftKnee', x: 290, y: 320),
          'rightKnee': PoseLandmark(name: 'rightKnee', x: 350, y: 320),
          'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 290, y: 420),
          'rightAnkle': PoseLandmark(name: 'rightAnkle', x: 350, y: 420),
        },
      );

      final eval = service.evaluateFrame(frame);
      expect(eval.isReady, isTrue);
      expect(eval.statusMessage, 'CAMERA READY');
      expect(eval.checklist.isFullBodyVisible, isTrue);
      expect(eval.guidanceCue, contains('Optimal positioning'));
    });

    test('shoulder exercise is ready with required upper-body joints only', () {
      final frame = PoseFrame(
        timestamp: DateTime.now(),
        imageWidth: 640,
        imageHeight: 480,
        landmarks: const {
          'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 280, y: 200),
          'rightShoulder': PoseLandmark(name: 'rightShoulder', x: 360, y: 200),
          'leftElbow': PoseLandmark(name: 'leftElbow', x: 270, y: 130),
          'rightElbow': PoseLandmark(name: 'rightElbow', x: 370, y: 130),
          'leftHip': PoseLandmark(name: 'leftHip', x: 290, y: 330),
          'rightHip': PoseLandmark(name: 'rightHip', x: 350, y: 330),
        },
      );

      final eval = service.evaluateFrame(
        frame,
        requiredLandmarks: ExerciseAnalysisConfig.shoulderFlexion.requiredLandmarks,
        config: ExerciseAnalysisConfig.shoulderFlexion,
      );

      expect(eval.isReady, isTrue);
      expect(eval.checklist.isFullBodyVisible, isFalse);
      expect(eval.guidanceCue, isNot(contains('Full body')));
    });

    test('upper-body readiness rejects a frame missing the exercise elbow', () {
      final frame = PoseFrame(
        timestamp: DateTime.now(),
        imageWidth: 640,
        imageHeight: 480,
        landmarks: const {
          'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 280, y: 200),
          'rightShoulder': PoseLandmark(name: 'rightShoulder', x: 360, y: 200),
          'leftHip': PoseLandmark(name: 'leftHip', x: 290, y: 330),
          'rightHip': PoseLandmark(name: 'rightHip', x: 350, y: 330),
        },
      );

      final eval = service.evaluateFrame(
        frame,
        requiredLandmarks: ExerciseAnalysisConfig.shoulderFlexion.requiredLandmarks,
        config: ExerciseAnalysisConfig.shoulderFlexion,
      );

      expect(eval.isReady, isFalse);
      expect(eval.guidanceCue, contains('elbow'));
    });

    test('squat still requires full-body framing when angle joints are visible', () {
      final frame = PoseFrame(
        timestamp: DateTime.now(),
        imageWidth: 640,
        imageHeight: 480,
        landmarks: const {
          'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 280, y: 100),
          'leftHip': PoseLandmark(name: 'leftHip', x: 290, y: 200),
          'leftKnee': PoseLandmark(name: 'leftKnee', x: 290, y: 300),
          'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 290, y: 400),
        },
      );

      final eval = service.evaluateFrame(
        frame,
        requiredLandmarks: ExerciseAnalysisConfig.squat.requiredLandmarks,
        config: ExerciseAnalysisConfig.squat,
      );

      expect(eval.isReady, isFalse);
      expect(eval.checklist.isFullBodyVisible, isFalse);
    });
  });
}
