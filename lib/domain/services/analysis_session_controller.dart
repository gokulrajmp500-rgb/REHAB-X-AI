import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../../data/repositories/local_rehab_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/camera_service.dart';
import '../../data/services/pose_detection_service.dart';
import '../models/pose_models.dart';
import 'camera_readiness_service.dart';
import 'exercise_analyzers.dart';
import 'human_presence_validator.dart';
import 'measurement_validator.dart';
import 'movement_features.dart';
import 'movement_quality_evaluator.dart';
import 'technique_feedback_service.dart';

enum AnalysisSessionStatus {
  idle,
  preparing,
  ready,
  running,
  paused,
  noHuman,
  lowConfidence,
  insufficientVisibility,
  multiPersonDetected,
  unavailable,
  completed,
  error,
}

class CameraDiagnostics {
  const CameraDiagnostics({
    this.fps = 0.0,
    this.poseFps = 0.0,
    this.latencyMs = 0,
    this.totalFrames = 0,
    this.validFrames = 0,
    this.droppedFrames = 0,
    this.averageConfidence = 0.0,
    this.imageResolution = '640x480',
    this.humanStatus = 'NO HUMAN',
  });

  final double fps;
  final double poseFps;
  final int latencyMs;
  final int totalFrames;
  final int validFrames;
  final int droppedFrames;
  final double averageConfidence;
  final String imageResolution;
  final String humanStatus;
}

class AnalysisSessionController extends ChangeNotifier {
  AnalysisSessionController({
    required this.camera,
    required this.pose,
    required this.sessions,
    required this.athleteId,
    required this.exerciseId,
    required this.exerciseName,
    required this.analyzer,
    this.planRepository,
    this.planId,
    this.planExerciseId,
  });

  final CameraService camera;
  final PoseDetectionService pose;
  final SessionRepository sessions;
  final String athleteId;
  final String exerciseId;
  final String exerciseName;
  final ExerciseAnalyzer analyzer;
  final RehabRepository? planRepository;
  final String? planId;
  final String? planExerciseId;

  final qualityEvaluator = const MovementQualityEvaluator();
  final cameraReadinessService = const CameraReadinessService();
  final humanValidator = const HumanPresenceValidator();
  final measurementValidator = const MeasurementValidator();
  final techniqueFeedbackService = const TechniqueFeedbackService();

  final _frames = <PoseFrame>[];

  AnalysisSessionStatus status = AnalysisSessionStatus.idle;
  String? errorMessage;
  MovementMetrics? liveMetrics;
  PoseFrame? latestPose;
  DateTime? startedAt;
  CameraReadinessEvaluation? readinessEvaluation;
  HumanValidationResult? humanValidation;
  RepetitionPhase currentPhase = RepetitionPhase.ready;
  String liveCoachingCue = 'Position your camera to begin';
  String movementIssue = 'No movement issue detected';
  String correctiveMethod =
      'Start the movement when your full body is visible.';
  String nextAttemptCue = 'Maintain controlled tempo throughout.';

  // Diagnostics
  int _totalCameraFrames = 0;
  int _droppedFrames = 0;
  DateTime? _lastFrameTime;
  double _currentFps = 0.0;
  int _currentLatencyMs = 0;

  CameraDiagnostics get diagnostics => CameraDiagnostics(
    fps: _currentFps,
    poseFps: _frames.isNotEmpty && elapsed.inSeconds > 0
        ? (_frames.length / elapsed.inSeconds)
        : 0.0,
    latencyMs: _currentLatencyMs,
    totalFrames: _totalCameraFrames,
    validFrames: _frames.length,
    droppedFrames: _droppedFrames,
    averageConfidence:
        humanValidation?.averageConfidence ??
        readinessEvaluation?.confidence ??
        0.0,
    imageResolution: latestPose?.imageWidth != null
        ? '${latestPose!.imageWidth}x${latestPose!.imageHeight}'
        : '640x480',
    humanStatus: humanValidation?.statusDisplayString ?? 'NO HUMAN',
  );

  bool isSimulationMode = false;
  Timer? _simulationTimer;
  double _simTimeSec = 0.0;

  bool get hasPoseData => _frames.isNotEmpty;
  bool get canStartAnalysis =>
      status == AnalysisSessionStatus.ready &&
      readinessEvaluation?.isReady == true &&
      humanValidation?.isValidForAnalysis == true;
  Duration get elapsed =>
      startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);

  void enableSimulationMode() {
    isSimulationMode = true;
    status = AnalysisSessionStatus.ready;
    _simTimeSec = 0.0;
    final initialPose = _generateSimulatedPose(0.0);
    latestPose = initialPose;
    humanValidation = humanValidator.validate(
      frame: initialPose,
      requiredLandmarks: analyzer.requiredLandmarks,
      config: analyzer.config,
    );
    readinessEvaluation = cameraReadinessService.evaluateFrame(
      initialPose,
      requiredLandmarks: analyzer.requiredLandmarks,
      config: analyzer.config,
    );
    liveCoachingCue = 'Simulator Mode: Click Start to run movement analysis';
    notifyListeners();
  }

  Future<void> initialize({bool frontCamera = false}) async {
    status = AnalysisSessionStatus.preparing;
    errorMessage = null;
    notifyListeners();
    try {
      await camera.initialize(frontCamera: frontCamera);
      await pose.initialize();
      if (!pose.isConfigured || camera.status == CameraStatus.unavailable) {
        status = AnalysisSessionStatus.unavailable;
        liveCoachingCue = 'Camera or pose model unavailable';
      } else {
        status = AnalysisSessionStatus.ready;
        liveCoachingCue = 'Step into frame for camera positioning';
        if (!isSimulationMode) {
          await camera.startImageStream(processFrame);
        }
      }
    } catch (error) {
      status = AnalysisSessionStatus.error;
      errorMessage = 'Camera or pose analysis could not be initialized: $error';
      liveCoachingCue = 'Initialization error';
    }
    notifyListeners();
  }

  Future<void> start() async {
    if (status != AnalysisSessionStatus.ready &&
        status != AnalysisSessionStatus.paused &&
        status != AnalysisSessionStatus.noHuman &&
        status != AnalysisSessionStatus.insufficientVisibility &&
        status != AnalysisSessionStatus.lowConfidence) {
      return;
    }
    if (readinessEvaluation?.isReady != true ||
        humanValidation?.isValidForAnalysis != true) {
      liveCoachingCue =
          humanValidation?.actionableCue ??
          readinessEvaluation?.guidanceCue ??
          'Wait until the required movement joints are visible.';
      notifyListeners();
      return;
    }
    startedAt ??= DateTime.now();
    status = AnalysisSessionStatus.running;
    liveCoachingCue = 'Maintain controlled movement';
    movementIssue = 'Checking movement technique';
    correctiveMethod =
        'Follow the on-screen correction as each repetition is measured.';
    if (isSimulationMode) {
      _simulationTimer?.cancel();
      _simulationTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
        _simTimeSec += 0.06;
        final frame = _generateSimulatedPose(_simTimeSec);
        processFrame(frame);
      });
    } else {
      await camera.startImageStream(processFrame);
    }
    notifyListeners();
  }

  Future<void> pause() async {
    if (status != AnalysisSessionStatus.running &&
        status != AnalysisSessionStatus.lowConfidence &&
        status != AnalysisSessionStatus.insufficientVisibility &&
        status != AnalysisSessionStatus.noHuman &&
        status != AnalysisSessionStatus.multiPersonDetected) {
      return;
    }
    if (isSimulationMode) {
      _simulationTimer?.cancel();
    } else {
      await camera.stopImageStream();
      await camera.pause();
    }
    status = AnalysisSessionStatus.paused;
    liveCoachingCue = 'Analysis paused';
    notifyListeners();
  }

  Future<void> resume() async {
    if (status != AnalysisSessionStatus.paused) return;
    if (isSimulationMode) {
      _simulationTimer?.cancel();
      _simulationTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
        _simTimeSec += 0.06;
        final frame = _generateSimulatedPose(_simTimeSec);
        processFrame(frame);
      });
    } else {
      await camera.resume();
      await camera.startImageStream(processFrame);
    }
    status = AnalysisSessionStatus.running;
    liveCoachingCue = 'Resuming analysis';
    notifyListeners();
  }

  Future<void> processFrame(Object frame) async {
    if (status != AnalysisSessionStatus.ready &&
        status != AnalysisSessionStatus.running &&
        status != AnalysisSessionStatus.lowConfidence &&
        status != AnalysisSessionStatus.insufficientVisibility &&
        status != AnalysisSessionStatus.noHuman &&
        status != AnalysisSessionStatus.multiPersonDetected) {
      return;
    }

    _totalCameraFrames++;
    final frameStartTime = DateTime.now();
    if (_lastFrameTime != null) {
      final delta = frameStartTime.difference(_lastFrameTime!).inMilliseconds;
      if (delta > 0) _currentFps = 1000.0 / delta;
    }
    _lastFrameTime = frameStartTime;

    PoseFrame? poseFrame;
    if (frame is PoseFrame) {
      poseFrame = frame;
    } else {
      try {
        poseFrame = await pose.processFrame(frame);
      } on Object catch (_) {
        status = AnalysisSessionStatus.error;
        errorMessage = 'Pose analysis failed while processing a camera frame.';
        liveCoachingCue = 'Frame processing error';
        notifyListeners();
        return;
      }
    }

    _currentLatencyMs = DateTime.now()
        .difference(frameStartTime)
        .inMilliseconds;

    if (poseFrame == null) {
      _droppedFrames++;
      return;
    }

    latestPose = poseFrame;

    // 1. Human Presence & Body Completeness Validation
    final validation = humanValidator.validate(
      frame: poseFrame,
      requiredLandmarks: analyzer.requiredLandmarks,
      config: analyzer.config,
    );
    humanValidation = validation;

    // Evaluate camera positioning readiness
    readinessEvaluation = cameraReadinessService.evaluateFrame(
      poseFrame,
      requiredLandmarks: analyzer.requiredLandmarks,
      config: analyzer.config,
    );

    // If still in ready state (before pressing Start), update live positioning cues and notify
    if (status == AnalysisSessionStatus.ready) {
      liveCoachingCue = validation.isValidForAnalysis
          ? (readinessEvaluation?.guidanceCue ?? 'Position yourself in frame')
          : validation.actionableCue;
      notifyListeners();
      return;
    }

    // 2. Reject Inanimate Objects / Shadows / Partial Bodies from entering analysis metrics
    if (!validation.isValidForAnalysis) {
      switch (validation.status) {
        case HumanPresenceStatus.noHuman:
          status = AnalysisSessionStatus.noHuman;
          liveCoachingCue = validation.actionableCue;
          movementIssue = 'Human body not detected in camera frame';
          correctiveMethod =
              'Ensure the athlete is in front of the camera with adequate room lighting.';
          break;
        case HumanPresenceStatus.multiplePeople:
          status = AnalysisSessionStatus.multiPersonDetected;
          liveCoachingCue = validation.actionableCue;
          movementIssue = 'Multiple people detected';
          correctiveMethod = 'Keep only one athlete in the camera viewport.';
          break;
        case HumanPresenceStatus.partialBody:
        case HumanPresenceStatus.insufficientForExercise:
        case HumanPresenceStatus.offScreen:
          status = AnalysisSessionStatus.insufficientVisibility;
          liveCoachingCue = validation.actionableCue;
          movementIssue = validation.actionableCue;
          correctiveMethod =
              'Step back so all required movement joints remain completely visible.';
          break;
        case HumanPresenceStatus.lowConfidence:
          status = AnalysisSessionStatus.lowConfidence;
          liveCoachingCue = validation.actionableCue;
          movementIssue = 'Low landmark tracking confidence';
          correctiveMethod =
              'Improve environment lighting and avoid heavy backlight/shadows.';
          break;
        case HumanPresenceStatus.validHuman:
          break;
      }
      notifyListeners();
      return;
    }

    // 3. Valid Human Detected -> Process Frame in Movement Sequence
    _frames.add(poseFrame);
    final sequence = PoseSequence(List.unmodifiable(_frames));

    if (sequence.dataConfidence < 0.5) {
      status = AnalysisSessionStatus.lowConfidence;
      liveCoachingCue = 'Low confidence — improve lighting and reposition';
      movementIssue =
          'The body landmarks are not clear enough to judge technique';
      correctiveMethod =
          'Move into better light and keep the complete body inside the camera frame.';
      notifyListeners();
      return;
    }

    if (!sequence.isSufficient ||
        !sequence.hasLandmarks(analyzer.requiredLandmarks)) {
      status = AnalysisSessionStatus.insufficientVisibility;
      liveCoachingCue = 'Keep your full body visible';
      movementIssue = 'Part of the movement is outside the camera view';
      correctiveMethod =
          'Step back and keep every required joint visible before repeating the exercise.';
      notifyListeners();
      return;
    }

    status = AnalysisSessionStatus.running;
    try {
      liveMetrics = analyzer.analyze(sequence);

      final technique = techniqueFeedbackService.evaluate(
        metrics: liveMetrics!,
        config: analyzer.config,
      );

      if (technique.hasIssue) {
        liveCoachingCue = technique.issue;
        movementIssue = technique.issue;
        correctiveMethod = technique.correction;
        nextAttemptCue = technique.nextAttemptCue;
      } else if (analyzer.config.requiresFullBody &&
          readinessEvaluation != null &&
          !readinessEvaluation!.checklist.isFullBodyVisible) {
        liveCoachingCue = 'Keep your full body visible';
        movementIssue = 'Full-body visibility is reduced';
        correctiveMethod =
            'Reposition the camera so your head, hips, knees, and ankles remain visible.';
        nextAttemptCue = 'Step back slightly.';
      } else {
        liveCoachingCue = 'Maintain controlled movement';
        movementIssue = 'No major technique issue detected';
        correctiveMethod =
            'Keep the same controlled tempo, range, and alignment.';
        nextAttemptCue = 'Repeat with identical form.';
      }

      notifyListeners();
    } on InsufficientMovementDataException {
      liveMetrics = null;
      notifyListeners();
    }
  }

  Future<SessionRecord?> finish() async {
    if (status == AnalysisSessionStatus.completed) return null;
    if (_frames.isEmpty) return null;
    _simulationTimer?.cancel();
    if (!isSimulationMode) {
      await camera.stopImageStream();
    }

    final sequence = PoseSequence(List.unmodifiable(_frames));

    // Basic sufficiency check
    if (!sequence.isSufficient ||
        !sequence.hasLandmarks(analyzer.requiredLandmarks) ||
        sequence.dataConfidence < 0.5) {
      throw const InsufficientMovementDataException(
        'Required landmarks were not visible for enough frames to complete a verified session.',
      );
    }

    final metrics = analyzer.analyze(sequence);
    final validRatio = _validFrameRatio(sequence);

    // Run the 9-point Validation Gate
    final validation = measurementValidator.validate(
      sequence: sequence,
      config: analyzer.config,
      metrics: metrics,
    );

    if (!validation.isValid) {
      throw InsufficientMovementDataException(
        validation.failureReason ??
            'Measurement validation gate criteria were not satisfied.',
      );
    }

    final report = qualityEvaluator.evaluate(
      metrics,
      validFrameRatio: validRatio,
    );

    final combinedObservations = <String>[
      ...report.observations,
      ...validation.observations,
    ];

    final combinedLimitations = <String>[
      ...report.limitations,
      ...validation.limitations,
      'Camera-based 2D movement analysis cannot replace professional clinical assessment.',
    ];

    final finalMetrics = MovementMetrics(
      rangeOfMotion: metrics.rangeOfMotion,
      symmetry: metrics.symmetry,
      consistency: metrics.consistency,
      stability: metrics.stability,
      velocity: metrics.velocity,
      tempo: metrics.tempo,
      dataConfidence: metrics.dataConfidence,
      validFrameRatio: validRatio,
      duration: metrics.duration,
      repetitions: metrics.repetitions,
      repetitionDetails: metrics.repetitionDetails,
      jointBreakdown: metrics.jointBreakdown,
      dataConfidenceState: validation.confidenceState,
      viewAngleObserved: analyzer.config.preferredCameraView.name,
      isMeasurementValid: true,
    );

    final session = SessionRecord(
      id: 'session-${DateTime.now().microsecondsSinceEpoch}',
      athleteId: athleteId,
      exercise: exerciseName,
      exerciseId: exerciseId,
      timestamp: DateTime.now(),
      metrics: finalMetrics,
      observations: combinedObservations,
      limitations: combinedLimitations,
      qualityLabel: report.overall.name,
      modelVersion: isSimulationMode
          ? 'web-kinematic-engine'
          : 'mlkit-2d-cv-pipeline',
      analysisStatus: 'measured',
      sourceMode: isSimulationMode ? 'simulation' : 'live',
    );

    await sessions.create(session);
    if (planRepository != null && planId != null && planExerciseId != null) {
      await planRepository!.completePlanExercise(planId!, planExerciseId!);
    }

    status = AnalysisSessionStatus.completed;
    liveCoachingCue = 'Analysis complete';
    notifyListeners();
    return session;
  }

  double _validFrameRatio(PoseSequence sequence) => sequence.frames.isEmpty
      ? 0
      : sequence.frames
                .where(
                  (frame) => frame.landmarks.values.any(
                    (landmark) => landmark.isValid,
                  ),
                )
                .length /
            sequence.frames.length;

  PoseFrame _generateSimulatedPose(double timeSec) {
    final cycleFreq = 0.45; // ~2.2 seconds per repetition cycle
    final phase = timeSec * cycleFreq * 2 * math.pi;
    final wave =
        (math.sin(phase) + 1) / 2; // 0.0 (standing) to 1.0 (bottom inflection)

    final hipY = 200.0 + (wave * 55.0);
    final kneeXLeft = 140.0 - (wave * 18.0);
    final kneeXRight = 180.0 + (wave * 18.0);
    final kneeY = 320.0 + (wave * 25.0);
    const ankleY = 440.0;

    final landmarks = <String, PoseLandmark>{
      'nose': const PoseLandmark(name: 'nose', x: 160, y: 70, confidence: 0.95),
      'leftEye': const PoseLandmark(
        name: 'leftEye',
        x: 154,
        y: 64,
        confidence: 0.95,
      ),
      'rightEye': const PoseLandmark(
        name: 'rightEye',
        x: 166,
        y: 64,
        confidence: 0.95,
      ),
      'leftShoulder': const PoseLandmark(
        name: 'leftShoulder',
        x: 125,
        y: 125,
        confidence: 0.94,
      ),
      'rightShoulder': const PoseLandmark(
        name: 'rightShoulder',
        x: 195,
        y: 125,
        confidence: 0.94,
      ),
      'shoulder': const PoseLandmark(
        name: 'shoulder',
        x: 160,
        y: 125,
        confidence: 0.94,
      ),
      'leftElbow': const PoseLandmark(
        name: 'leftElbow',
        x: 105,
        y: 175,
        confidence: 0.91,
      ),
      'rightElbow': const PoseLandmark(
        name: 'rightElbow',
        x: 215,
        y: 175,
        confidence: 0.91,
      ),
      'leftWrist': const PoseLandmark(
        name: 'leftWrist',
        x: 95,
        y: 220,
        confidence: 0.89,
      ),
      'rightWrist': const PoseLandmark(
        name: 'rightWrist',
        x: 225,
        y: 220,
        confidence: 0.89,
      ),
      'leftHip': PoseLandmark(
        name: 'leftHip',
        x: 135,
        y: hipY,
        confidence: 0.93,
      ),
      'rightHip': PoseLandmark(
        name: 'rightHip',
        x: 185,
        y: hipY,
        confidence: 0.93,
      ),
      'hip': PoseLandmark(name: 'hip', x: 160, y: hipY, confidence: 0.93),
      'leftKnee': PoseLandmark(
        name: 'leftKnee',
        x: kneeXLeft,
        y: kneeY,
        confidence: 0.95,
      ),
      'rightKnee': PoseLandmark(
        name: 'rightKnee',
        x: kneeXRight,
        y: kneeY,
        confidence: 0.95,
      ),
      'knee': PoseLandmark(name: 'knee', x: 160, y: kneeY, confidence: 0.95),
      'leftAnkle': const PoseLandmark(
        name: 'leftAnkle',
        x: 135,
        y: ankleY,
        confidence: 0.92,
      ),
      'rightAnkle': const PoseLandmark(
        name: 'rightAnkle',
        x: 185,
        y: ankleY,
        confidence: 0.92,
      ),
      'ankle': const PoseLandmark(
        name: 'ankle',
        x: 160,
        y: ankleY,
        confidence: 0.92,
      ),
      'leftHeel': const PoseLandmark(
        name: 'leftHeel',
        x: 130,
        y: ankleY + 8,
        confidence: 0.88,
      ),
      'rightHeel': const PoseLandmark(
        name: 'rightHeel',
        x: 190,
        y: ankleY + 8,
        confidence: 0.88,
      ),
      'leftFootIndex': const PoseLandmark(
        name: 'leftFootIndex',
        x: 140,
        y: ankleY + 12,
        confidence: 0.88,
      ),
      'rightFootIndex': const PoseLandmark(
        name: 'rightFootIndex',
        x: 180,
        y: ankleY + 12,
        confidence: 0.88,
      ),
    };

    return PoseFrame(
      timestamp: DateTime.now(),
      landmarks: landmarks,
      imageWidth: 320,
      imageHeight: 480,
      personCount: 1,
      isMultiPerson: false,
    );
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    camera.dispose();
    pose.dispose();
    super.dispose();
  }
}
