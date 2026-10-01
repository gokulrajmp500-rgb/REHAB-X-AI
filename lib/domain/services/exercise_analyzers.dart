import '../../core/utils/joint_angle_calculator.dart';
import '../models/exercise_analysis_config.dart';
import '../models/pose_models.dart';
import 'joint_telemetry_service.dart';
import 'movement_features.dart';

export 'movement_features.dart' show InsufficientMovementDataException;

abstract interface class ExerciseAnalyzer {
  String get exerciseId;
  List<String> get requiredLandmarks;
  ExerciseAnalysisConfig get config;
  MovementMetrics analyze(PoseSequence sequence);
}

class SquatAnalyzer implements ExerciseAnalyzer {
  const SquatAnalyzer({this.thresholds = const AnalyzerThresholds()});
  final AnalyzerThresholds thresholds;

  @override
  String get exerciseId => 'squat';

  @override
  List<String> get requiredLandmarks => const ['hip', 'knee', 'ankle'];

  @override
  ExerciseAnalysisConfig get config => ExerciseAnalysisConfig.squat;

  @override
  MovementMetrics analyze(PoseSequence sequence) => _lowerBodyMetrics(sequence, thresholds, config);
}

class LungeAnalyzer implements ExerciseAnalyzer {
  const LungeAnalyzer({this.thresholds = const AnalyzerThresholds()});
  final AnalyzerThresholds thresholds;

  @override
  String get exerciseId => 'lunge';

  @override
  List<String> get requiredLandmarks => const ['hip', 'knee', 'ankle'];

  @override
  ExerciseAnalysisConfig get config => ExerciseAnalysisConfig.lunge;

  @override
  MovementMetrics analyze(PoseSequence sequence) => _lowerBodyMetrics(sequence, thresholds, config);
}

class SingleLegBalanceAnalyzer implements ExerciseAnalyzer {
  @override
  String get exerciseId => 'balance';

  @override
  List<String> get requiredLandmarks => const ['hip', 'ankle'];

  @override
  ExerciseAnalysisConfig get config => ExerciseAnalysisConfig.singleLegBalance;

  @override
  MovementMetrics analyze(PoseSequence sequence) {
    if (!sequence.isSufficient) throw const InsufficientMovementDataException();
    final duration = sequence.frames.last.timestamp.difference(sequence.frames.first.timestamp);
    final hip = sequence.frames.map((frame) => frame.landmarks['hip']).whereType<PoseLandmark>().toList();
    final sway = hip.isEmpty
        ? null
        : hip.map((l) => l.x).reduce((a, b) => a > b ? a : b) - hip.map((l) => l.x).reduce((a, b) => a < b ? a : b);
    if (sway == null) throw const InsufficientMovementDataException();
    final validFrames = sequence.frames
        .where((frame) => frame.landmarks['hip']?.isValid == true && frame.landmarks['ankle']?.isValid == true)
        .length;
    final jointBreakdown = const JointTelemetryService().analyzeAllKeyJoints(sequence);
    final validRatio = validFrames / sequence.frames.length;

    return MovementMetrics(
      rangeOfMotion: 0,
      symmetry: null,
      consistency: (100 - sway * 100).clamp(0, 100),
      stability: (100 - sway * 100).clamp(0, 100),
      duration: duration,
      repetitions: 0,
      dataConfidence: sequence.dataConfidence,
      validFrameRatio: validRatio,
      jointBreakdown: jointBreakdown,
      dataConfidenceState: _confidenceState(sequence.dataConfidence, validRatio),
      viewAngleObserved: 'front',
      isMeasurementValid: validRatio >= config.minimumValidFrameRatio && sequence.dataConfidence >= config.minimumConfidence,
    );
  }
}

class ShoulderFlexionAnalyzer implements ExerciseAnalyzer {
  const ShoulderFlexionAnalyzer({
    this.thresholds = const AnalyzerThresholds(isFlexionFirst: false, minimumRepAngleChange: 20),
  });
  final AnalyzerThresholds thresholds;

  @override
  String get exerciseId => 'shoulder_flexion';

  @override
  List<String> get requiredLandmarks => const ['shoulder', 'elbow', 'hip'];

  @override
  ExerciseAnalysisConfig get config => ExerciseAnalysisConfig.shoulderFlexion;

  @override
  MovementMetrics analyze(PoseSequence sequence) => _shoulderMetrics(sequence, thresholds, config);
}

class ShoulderAbductionAnalyzer implements ExerciseAnalyzer {
  const ShoulderAbductionAnalyzer({
    this.thresholds = const AnalyzerThresholds(isFlexionFirst: false, minimumRepAngleChange: 20),
  });
  final AnalyzerThresholds thresholds;

  @override
  String get exerciseId => 'shoulder_abduction';

  @override
  List<String> get requiredLandmarks => const ['shoulder', 'elbow', 'hip'];

  @override
  ExerciseAnalysisConfig get config => ExerciseAnalysisConfig.shoulderAbduction;

  @override
  MovementMetrics analyze(PoseSequence sequence) => _shoulderMetrics(sequence, thresholds, config);
}

class CalfRaiseAnalyzer implements ExerciseAnalyzer {
  const CalfRaiseAnalyzer({
    this.thresholds = const AnalyzerThresholds(isFlexionFirst: false, minimumRepAngleChange: 10),
  });
  final AnalyzerThresholds thresholds;

  @override
  String get exerciseId => 'calf_raise';

  @override
  List<String> get requiredLandmarks => const ['knee', 'ankle', 'foot'];

  @override
  ExerciseAnalysisConfig get config => ExerciseAnalysisConfig.calfRaise;

  @override
  MovementMetrics analyze(PoseSequence sequence) {
    final features = extractAngleFeatures(sequence, first: 'knee', vertex: 'ankle', third: 'foot', thresholds: thresholds);
    final jointBreakdown = const JointTelemetryService().analyzeAllKeyJoints(sequence);
    return MovementMetrics(
      rangeOfMotion: features.rangeOfMotion,
      symmetry: _bilateralDifference(sequence, 'knee', 'ankle', 'foot'),
      consistency: features.consistency,
      duration: features.duration,
      repetitions: features.repetitions,
      velocity: features.velocity,
      tempo: features.tempo,
      dataConfidence: features.confidence,
      validFrameRatio: features.validFrameRatio,
      repetitionDetails: features.repetitionDetails,
      jointBreakdown: jointBreakdown,
      dataConfidenceState: _confidenceState(features.confidence, features.validFrameRatio),
      viewAngleObserved: 'side',
      isMeasurementValid: features.validFrameRatio >= config.minimumValidFrameRatio && features.confidence >= config.minimumConfidence,
    );
  }
}

class HipHingeAnalyzer implements ExerciseAnalyzer {
  const HipHingeAnalyzer({this.thresholds = const AnalyzerThresholds()});
  final AnalyzerThresholds thresholds;

  @override
  String get exerciseId => 'hip_hinge';

  @override
  List<String> get requiredLandmarks => const ['shoulder', 'hip', 'knee'];

  @override
  ExerciseAnalysisConfig get config => ExerciseAnalysisConfig.hipHinge;

  @override
  MovementMetrics analyze(PoseSequence sequence) {
    final features = extractAngleFeatures(sequence, first: 'shoulder', vertex: 'hip', third: 'knee', thresholds: thresholds);
    final jointBreakdown = const JointTelemetryService().analyzeAllKeyJoints(sequence);
    return MovementMetrics(
      rangeOfMotion: features.rangeOfMotion,
      symmetry: _bilateralDifference(sequence, 'shoulder', 'hip', 'knee'),
      consistency: features.consistency,
      duration: features.duration,
      repetitions: features.repetitions,
      velocity: features.velocity,
      tempo: features.tempo,
      dataConfidence: features.confidence,
      validFrameRatio: features.validFrameRatio,
      repetitionDetails: features.repetitionDetails,
      jointBreakdown: jointBreakdown,
      dataConfidenceState: _confidenceState(features.confidence, features.validFrameRatio),
      viewAngleObserved: 'side',
      isMeasurementValid: features.validFrameRatio >= config.minimumValidFrameRatio && features.confidence >= config.minimumConfidence,
    );
  }
}

class ElbowFlexionAnalyzer implements ExerciseAnalyzer {
  const ElbowFlexionAnalyzer({
    this.thresholds = const AnalyzerThresholds(isFlexionFirst: true, minimumRepAngleChange: 20),
  });
  final AnalyzerThresholds thresholds;

  @override
  String get exerciseId => 'elbow_flexion';

  @override
  List<String> get requiredLandmarks => const ['shoulder', 'elbow', 'wrist'];

  @override
  ExerciseAnalysisConfig get config => ExerciseAnalysisConfig.elbowFlexion;

  @override
  MovementMetrics analyze(PoseSequence sequence) {
    final features = extractAngleFeatures(sequence, first: 'shoulder', vertex: 'elbow', third: 'wrist', thresholds: thresholds);
    final jointBreakdown = const JointTelemetryService().analyzeAllKeyJoints(sequence);
    return MovementMetrics(
      rangeOfMotion: features.rangeOfMotion,
      symmetry: _bilateralDifference(sequence, 'shoulder', 'elbow', 'wrist'),
      consistency: features.consistency,
      duration: features.duration,
      repetitions: features.repetitions,
      velocity: features.velocity,
      tempo: features.tempo,
      dataConfidence: features.confidence,
      validFrameRatio: features.validFrameRatio,
      repetitionDetails: features.repetitionDetails,
      jointBreakdown: jointBreakdown,
      dataConfidenceState: _confidenceState(features.confidence, features.validFrameRatio),
      viewAngleObserved: 'side',
      isMeasurementValid: features.validFrameRatio >= config.minimumValidFrameRatio && features.confidence >= config.minimumConfidence,
    );
  }
}

class PushUpAnalyzer implements ExerciseAnalyzer {
  const PushUpAnalyzer({this.thresholds = const AnalyzerThresholds()});
  final AnalyzerThresholds thresholds;

  @override
  String get exerciseId => 'push_up';

  @override
  List<String> get requiredLandmarks => const ['shoulder', 'elbow', 'wrist'];

  @override
  ExerciseAnalysisConfig get config => ExerciseAnalysisConfig.pushUp;

  @override
  MovementMetrics analyze(PoseSequence sequence) {
    final features = extractAngleFeatures(sequence, first: 'shoulder', vertex: 'elbow', third: 'wrist', thresholds: thresholds);
    final jointBreakdown = const JointTelemetryService().analyzeAllKeyJoints(sequence);
    return MovementMetrics(
      rangeOfMotion: features.rangeOfMotion,
      symmetry: _bilateralDifference(sequence, 'shoulder', 'elbow', 'wrist'),
      consistency: features.consistency,
      duration: features.duration,
      repetitions: features.repetitions,
      velocity: features.velocity,
      tempo: features.tempo,
      dataConfidence: features.confidence,
      validFrameRatio: features.validFrameRatio,
      repetitionDetails: features.repetitionDetails,
      jointBreakdown: jointBreakdown,
      dataConfidenceState: _confidenceState(features.confidence, features.validFrameRatio),
      viewAngleObserved: 'side',
      isMeasurementValid: features.validFrameRatio >= config.minimumValidFrameRatio && features.confidence >= config.minimumConfidence,
    );
  }
}

ExerciseAnalyzer? getExerciseAnalyzer(String id) => switch (id) {
      'squat' || 'deep_squat' => const SquatAnalyzer(),
      'lunge' || 'reverse_lunge' || 'forward_lunge' || 'split_squat' => const LungeAnalyzer(),
      'balance' => SingleLegBalanceAnalyzer(),
      'shoulder_flexion' || 'arm_raise' => const ShoulderFlexionAnalyzer(),
      'shoulder_abduction' => const ShoulderAbductionAnalyzer(),
      'calf_raise' => const CalfRaiseAnalyzer(),
      'hip_hinge' => const HipHingeAnalyzer(),
      'elbow_flexion' => const ElbowFlexionAnalyzer(),
      'push_up' => const PushUpAnalyzer(),
      _ => null,
    };

MovementMetrics _lowerBodyMetrics(PoseSequence sequence, AnalyzerThresholds thresholds, ExerciseAnalysisConfig config) {
  final features = extractAngleFeatures(sequence, first: 'hip', vertex: 'knee', third: 'ankle', thresholds: thresholds);
  final jointBreakdown = const JointTelemetryService().analyzeAllKeyJoints(sequence);
  return MovementMetrics(
    rangeOfMotion: features.rangeOfMotion,
    symmetry: _bilateralDifference(sequence, 'hip', 'knee', 'ankle'),
    consistency: features.consistency,
    duration: features.duration,
    repetitions: features.repetitions,
    velocity: features.velocity,
    tempo: features.tempo,
    dataConfidence: features.confidence,
    validFrameRatio: features.validFrameRatio,
    repetitionDetails: features.repetitionDetails,
    jointBreakdown: jointBreakdown,
    dataConfidenceState: _confidenceState(features.confidence, features.validFrameRatio),
    viewAngleObserved: 'side',
    isMeasurementValid: features.validFrameRatio >= config.minimumValidFrameRatio && features.confidence >= config.minimumConfidence,
  );
}

MovementMetrics _shoulderMetrics(PoseSequence sequence, AnalyzerThresholds thresholds, ExerciseAnalysisConfig config) {
  final features = extractAngleFeatures(sequence, first: 'elbow', vertex: 'shoulder', third: 'hip', thresholds: thresholds);
  final jointBreakdown = const JointTelemetryService().analyzeAllKeyJoints(sequence);
  return MovementMetrics(
    rangeOfMotion: features.rangeOfMotion,
    symmetry: _bilateralDifference(sequence, 'elbow', 'shoulder', 'hip'),
    consistency: features.consistency,
    duration: features.duration,
    repetitions: features.repetitions,
    velocity: features.velocity,
    tempo: features.tempo,
    dataConfidence: features.confidence,
    validFrameRatio: features.validFrameRatio,
    repetitionDetails: features.repetitionDetails,
    jointBreakdown: jointBreakdown,
    dataConfidenceState: _confidenceState(features.confidence, features.validFrameRatio),
    viewAngleObserved: config.preferredCameraView.name,
    isMeasurementValid: features.validFrameRatio >= config.minimumValidFrameRatio && features.confidence >= config.minimumConfidence,
  );
}

double? _bilateralDifference(PoseSequence sequence, String first, String vertex, String third) {
  final leftAngles = <double>[];
  final rightAngles = <double>[];
  for (final frame in sequence.frames) {
    final left = _angleFor(frame, 'left${_capitalized(first)}', 'left${_capitalized(vertex)}', 'left${_capitalized(third)}');
    final right = _angleFor(frame, 'right${_capitalized(first)}', 'right${_capitalized(vertex)}', 'right${_capitalized(third)}');
    if (left != null && right != null) {
      leftAngles.add(left);
      rightAngles.add(right);
    }
  }
  if (leftAngles.isEmpty) return null;
  final leftMean = leftAngles.reduce((a, b) => a + b) / leftAngles.length;
  final rightMean = rightAngles.reduce((a, b) => a + b) / rightAngles.length;
  final denominator = ((leftMean.abs() + rightMean.abs()) / 2).clamp(0.0001, double.infinity);
  return ((leftMean - rightMean).abs() / denominator * 100).clamp(0, 100);
}

String _capitalized(String value) => value[0].toUpperCase() + value.substring(1);

double? _angleFor(PoseFrame frame, String first, String vertex, String third) {
  final a = frame.landmarks[first];
  final b = frame.landmarks[vertex];
  final c = frame.landmarks[third];
  return JointAngleCalculator.calculateAngle(a, b, c);
}

String _confidenceState(double confidence, double validFrameRatio) {
  if (confidence >= 0.80 && validFrameRatio >= 0.80) return 'HIGH';
  if (confidence >= 0.65 && validFrameRatio >= 0.65) return 'MODERATE';
  if (confidence >= 0.50 && validFrameRatio >= 0.50) return 'LOW';
  return 'INSUFFICIENT';
}
