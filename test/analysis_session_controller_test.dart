import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/data/repositories/session_repository.dart';
import 'package:flutter_application_1/data/repositories/local_rehab_repository.dart';
import 'package:flutter_application_1/data/services/camera_service.dart';
import 'package:flutter_application_1/data/services/pose_detection_service.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/models/personalized_plan.dart';
import 'package:flutter_application_1/domain/services/analysis_session_controller.dart';
import 'package:flutter_application_1/domain/services/exercise_analyzers.dart';

void main() {
  test('unconfigured providers produce an unavailable session state', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AnalysisSessionController(camera: UnavailableCameraService(), pose: UnavailablePoseDetectionService(), sessions: LocalSessionRepository(await SharedPreferences.getInstance()), athleteId: 'athlete', exerciseId: 'squat', exerciseName: 'Squat', analyzer: SquatAnalyzer());
    await controller.initialize();
    expect(controller.status, AnalysisSessionStatus.unavailable);
    controller.dispose();
  });

  test('analysis cannot start before required joints are visible', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AnalysisSessionController(
      camera: _ReadyCamera(),
      pose: _MeasuredPose(),
      sessions: LocalSessionRepository(await SharedPreferences.getInstance()),
      athleteId: 'athlete',
      exerciseId: 'squat',
      exerciseName: 'Squat',
      analyzer: SquatAnalyzer(),
    );
    await controller.initialize();

    await controller.start();
    expect(controller.status, AnalysisSessionStatus.ready);
    expect(controller.startedAt, isNull);
    expect(controller.canStartAnalysis, isFalse);

    await controller.processFrame(Object());
    expect(controller.canStartAnalysis, isTrue);
    await controller.start();
    expect(controller.status, AnalysisSessionStatus.running);
    controller.dispose();
  });

  test('configured providers complete and persist a measured session', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalSessionRepository(preferences);
    final controller = AnalysisSessionController(camera: _ReadyCamera(), pose: _MeasuredPose(), sessions: repository, athleteId: 'athlete', exerciseId: 'squat', exerciseName: 'Squat', analyzer: SquatAnalyzer());
    await controller.initialize();
    expect(controller.status, AnalysisSessionStatus.ready);
    await controller.processFrame(Object());
    await controller.start();
    await controller.processFrame(Object());
    await controller.processFrame(Object());
    await controller.processFrame(Object());
    final session = await controller.finish();

    expect(session?.analysisStatus, 'measured');
    expect((await repository.readAll('athlete')).length, 1);
    controller.dispose();
  });

  test('valid completion updates the linked plan exercise once', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final planRepository = LocalRehabRepository(preferences);
    await planRepository.savePlan(PersonalizedPlan(title: 'Plan', focusArea: 'Consistency', stage: 'Mobility', exercises: const [PlanExercise(exerciseId: 'squat', name: 'Squat', target: 'Control', sets: 1, repetitions: 1)], frequency: 'weekly', progressionCriteria: 'two sessions', monitoringMetrics: const ['ROM'], recoveryGuidance: 'Rest', limitations: const [], generatedAt: DateTime(2026), athleteId: 'athlete'));
    final controller = AnalysisSessionController(camera: _ReadyCamera(), pose: _MeasuredPose(), sessions: LocalSessionRepository(preferences), planRepository: planRepository, planId: 'plan-1', planExerciseId: 'squat', athleteId: 'athlete', exerciseId: 'squat', exerciseName: 'Squat', analyzer: SquatAnalyzer());
    await controller.initialize();
    await controller.processFrame(Object());
    await controller.start();
    for (var index = 0; index < 3; index++) { await controller.processFrame(Object()); }
    await controller.finish();
    final progress = await planRepository.loadPlanProgress();
    expect(progress?.completedExerciseIds, contains('squat'));
    controller.dispose();
  });

  test('duplicate finish does not create a second session', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalSessionRepository(preferences);
    final controller = AnalysisSessionController(camera: _ReadyCamera(), pose: _MeasuredPose(), sessions: repository, athleteId: 'athlete', exerciseId: 'squat', exerciseName: 'Squat', analyzer: SquatAnalyzer());
    await controller.initialize();
    await controller.processFrame(Object());
    await controller.start();
    for (var index = 0; index < 3; index++) { await controller.processFrame(Object()); }
    expect(await controller.finish(), isNotNull);
    expect(await controller.finish(), isNull);
    expect((await repository.readAll('athlete')).length, 1);
    controller.dispose();
  });
}

class _ReadyCamera implements CameraService {
  @override CameraStatus status = CameraStatus.ready;
  @override CameraController? get controller => null;
  @override Future<void> initialize({bool frontCamera = false}) async {}
  @override Future<void> pause() async {}
  @override Future<void> resume() async {}
  @override Future<void> startImageStream(CameraFrameCallback callback) async {}
  @override Future<void> stopImageStream() async {}
  @override Future<void> dispose() async {}
}

class _MeasuredPose implements PoseDetectionService {
  var _index = 0;
  @override bool get isConfigured => true;
  @override Future<void> initialize() async {}
  @override Future<void> dispose() async {}
  @override Future<PoseFrame?> processFrame(Object frame) async {
    final timestamp = DateTime(2026, 1, 1).add(Duration(seconds: _index++));
    return PoseFrame(
      timestamp: timestamp,
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
        'hip': PoseLandmark(name: 'hip', x: 290, y: 240, confidence: 0.95),
        'knee': PoseLandmark(name: 'knee', x: 295, y: 340, confidence: 0.95),
        'ankle': PoseLandmark(name: 'ankle', x: 300, y: 440, confidence: 0.95),
      },
    );
  }
}