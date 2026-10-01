import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/widgets/body_silhouette_painter.dart';
import 'package:flutter_application_1/domain/models/exercise_analysis_config.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/services/joint_telemetry_service.dart';

void main() {
  group('JointTelemetryService', () {
    const service = JointTelemetryService();

    test('returns zero values for insufficient sequence', () {
      const emptySequence = PoseSequence([]);
      final result = service.analyzeJoint(emptySequence, AnatomicalJoint.leftKnee);

      expect(result.currentAngle, 0);
      expect(result.rangeOfMotion, 0);
      expect(result.observation, contains('Insufficient'));
    });

    test('calculates knee joint angle and ROM from valid sequence', () {
      final now = DateTime.now();
      final frames = [
        PoseFrame(
          timestamp: now,
          landmarks: const {
            'leftHip': PoseLandmark(name: 'leftHip', x: 100, y: 100),
            'leftKnee': PoseLandmark(name: 'leftKnee', x: 100, y: 200),
            'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 100, y: 300),
          },
        ),
        PoseFrame(
          timestamp: now.add(const Duration(milliseconds: 100)),
          landmarks: const {
            'leftHip': PoseLandmark(name: 'leftHip', x: 100, y: 100),
            'leftKnee': PoseLandmark(name: 'leftKnee', x: 150, y: 200),
            'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 100, y: 300),
          },
        ),
        PoseFrame(
          timestamp: now.add(const Duration(milliseconds: 200)),
          landmarks: const {
            'leftHip': PoseLandmark(name: 'leftHip', x: 100, y: 100),
            'leftKnee': PoseLandmark(name: 'leftKnee', x: 100, y: 200),
            'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 100, y: 300),
          },
        ),
      ];

      final sequence = PoseSequence(frames);
      final report = service.analyzeJoint(sequence, AnatomicalJoint.leftKnee);

      expect(report.currentAngle, isNonZero);
      expect(report.rangeOfMotion, greaterThan(0));
      expect(report.displayName, 'Left Knee');
    });

    test('measures the exercise joint instead of always reporting a knee', () {
      final frame = PoseFrame(
        timestamp: DateTime.utc(2026),
        landmarks: const {
          'leftElbow': PoseLandmark(name: 'leftElbow', x: 100, y: 100),
          'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 100, y: 200),
          'leftHip': PoseLandmark(name: 'leftHip', x: 200, y: 200),
        },
      );

      expect(
        service.primaryAngle(frame, ExerciseAnalysisConfig.shoulderFlexion),
        closeTo(90, 0.001),
      );
      expect(service.primaryAngle(null, ExerciseAnalysisConfig.squat), isNull);
    });

    test('calf raise primary angle uses knee, ankle, and foot', () {
      final frame = PoseFrame(
        timestamp: DateTime.utc(2026),
        landmarks: const {
          'leftKnee': PoseLandmark(name: 'leftKnee', x: 0, y: 0),
          'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 0, y: 100),
          'leftFootIndex': PoseLandmark(name: 'leftFootIndex', x: 100, y: 100),
        },
      );

      expect(
        service.primaryAngle(frame, ExerciseAnalysisConfig.calfRaise),
        closeTo(90, 0.001),
      );
    });

    test('primary angle mappings cover every configured angle exercise', () {
      final frame = PoseFrame(
        timestamp: DateTime.utc(2026),
        landmarks: const {
          'leftShoulder': PoseLandmark(name: 'leftShoulder', x: 100, y: 100),
          'leftElbow': PoseLandmark(name: 'leftElbow', x: 80, y: 150),
          'leftWrist': PoseLandmark(name: 'leftWrist', x: 60, y: 200),
          'leftHip': PoseLandmark(name: 'leftHip', x: 100, y: 200),
          'leftKnee': PoseLandmark(name: 'leftKnee', x: 100, y: 300),
          'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 100, y: 400),
          'leftFootIndex': PoseLandmark(name: 'leftFootIndex', x: 150, y: 400),
        },
      );
      const configs = [
        ExerciseAnalysisConfig.squat,
        ExerciseAnalysisConfig.lunge,
        ExerciseAnalysisConfig.shoulderFlexion,
        ExerciseAnalysisConfig.shoulderAbduction,
        ExerciseAnalysisConfig.calfRaise,
        ExerciseAnalysisConfig.hipHinge,
        ExerciseAnalysisConfig.elbowFlexion,
        ExerciseAnalysisConfig.pushUp,
      ];

      for (final config in configs) {
        expect(
          service.primaryAngle(frame, config),
          isNotNull,
          reason: '${config.displayName} should have a spoken angle source',
        );
      }
      expect(
        service.primaryAngle(frame, ExerciseAnalysisConfig.singleLegBalance),
        isNull,
      );
    });

    test('analyzes all key joints and returns structured summary map', () {
      final now = DateTime.now();
      final frames = [
        PoseFrame(
          timestamp: now,
          landmarks: const {
            'leftHip': PoseLandmark(name: 'leftHip', x: 100, y: 100),
            'leftKnee': PoseLandmark(name: 'leftKnee', x: 100, y: 200),
            'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 100, y: 300),
            'rightHip': PoseLandmark(name: 'rightHip', x: 200, y: 100),
            'rightKnee': PoseLandmark(name: 'rightKnee', x: 200, y: 200),
            'rightAnkle': PoseLandmark(name: 'rightAnkle', x: 200, y: 300),
          },
        ),
        PoseFrame(
          timestamp: now.add(const Duration(milliseconds: 100)),
          landmarks: const {
            'leftHip': PoseLandmark(name: 'leftHip', x: 100, y: 100),
            'leftKnee': PoseLandmark(name: 'leftKnee', x: 140, y: 200),
            'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 100, y: 300),
            'rightHip': PoseLandmark(name: 'rightHip', x: 200, y: 100),
            'rightKnee': PoseLandmark(name: 'rightKnee', x: 240, y: 200),
            'rightAnkle': PoseLandmark(name: 'rightAnkle', x: 200, y: 300),
          },
        ),
        PoseFrame(
          timestamp: now.add(const Duration(milliseconds: 200)),
          landmarks: const {
            'leftHip': PoseLandmark(name: 'leftHip', x: 100, y: 100),
            'leftKnee': PoseLandmark(name: 'leftKnee', x: 100, y: 200),
            'leftAnkle': PoseLandmark(name: 'leftAnkle', x: 100, y: 300),
            'rightHip': PoseLandmark(name: 'rightHip', x: 200, y: 100),
            'rightKnee': PoseLandmark(name: 'rightKnee', x: 200, y: 200),
            'rightAnkle': PoseLandmark(name: 'rightAnkle', x: 200, y: 300),
          },
        ),
      ];

      final sequence = PoseSequence(frames);
      final all = service.analyzeAllKeyJoints(sequence);

      expect(all.containsKey('Left Knee'), isTrue);
      expect(all.containsKey('Right Knee'), isTrue);
      expect(all['Left Knee']!.rangeOfMotion, greaterThan(0));
    });
  });
}
