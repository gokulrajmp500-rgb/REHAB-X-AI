import 'dart:math' as math;

import '../../core/filters/outlier_detector.dart';
import '../models/pose_models.dart';

class MovementFeatures {
  const MovementFeatures({
    required this.angles,
    required this.rangeOfMotion,
    required this.duration,
    required this.velocity,
    required this.consistency,
    required this.repetitions,
    required this.confidence,
    required this.validFrameRatio,
    this.tempo,
    this.repetitionDetails = const [],
    this.minAngle,
    this.maxAngle,
  });

  final List<double> angles;
  final double rangeOfMotion;
  final Duration duration;
  final double velocity;
  final double consistency;
  final int repetitions;
  final double confidence;
  final double validFrameRatio;
  final double? tempo;
  final List<RepetitionDetail> repetitionDetails;
  final double? minAngle;
  final double? maxAngle;
}

class AnalyzerThresholds {
  const AnalyzerThresholds({
    this.minimumLandmarkConfidence = 0.5,
    this.minimumRepAngleChange = 15,
    this.controlledVelocity = 1.5,
    this.isFlexionFirst = true,
  });

  final double minimumLandmarkConfidence;
  final double minimumRepAngleChange;
  final double controlledVelocity;
  final bool isFlexionFirst;
}

enum RepetitionPhase { ready, descending, bottom, ascending, completed }

class RepetitionStateMachine {
  RepetitionStateMachine({
    this.minimumAngleChange = 15,
    this.isFlexionFirst = true,
  });

  final double minimumAngleChange;
  final bool isFlexionFirst;

  RepetitionPhase phase = RepetitionPhase.ready;
  double? _startAngle;
  double? _extremumAngleDuringRep;
  double? _repStartTimeSec;
  double? _inflectionTimeSec;
  int _currentIndex = 0;
  int count = 0;
  final List<RepetitionDetail> details = [];

  int add(double angle, {double? timestampSeconds}) {
    final t = timestampSeconds ?? (_currentIndex * 0.033);
    _startAngle ??= angle;

    if (isFlexionFirst) {
      _extremumAngleDuringRep = math.min(_extremumAngleDuringRep ?? angle, angle);
    } else {
      _extremumAngleDuringRep = math.max(_extremumAngleDuringRep ?? angle, angle);
    }

    switch (phase) {
      case RepetitionPhase.ready:
        final delta = isFlexionFirst ? (_startAngle! - angle) : (angle - _startAngle!);
        if (delta >= minimumAngleChange) {
          phase = RepetitionPhase.descending;
          _repStartTimeSec = t;
          _extremumAngleDuringRep = angle;
        }
      case RepetitionPhase.descending:
        final delta = isFlexionFirst ? (_startAngle! - angle) : (angle - _startAngle!);
        if (delta >= minimumAngleChange * 1.5) {
          phase = RepetitionPhase.bottom;
          _inflectionTimeSec = t;
        } else if (delta <= minimumAngleChange / 3) {
          // Reverted back to start without completing descent
          phase = RepetitionPhase.ready;
        }
      case RepetitionPhase.bottom:
        final delta = isFlexionFirst ? (_startAngle! - angle) : (angle - _startAngle!);
        if (delta <= minimumAngleChange) {
          phase = RepetitionPhase.ascending;
        }
      case RepetitionPhase.ascending:
        final delta = isFlexionFirst ? (_startAngle! - angle) : (angle - _startAngle!);
        if (delta <= minimumAngleChange / 2) {
          phase = RepetitionPhase.completed;
          final rom = (_startAngle! - (_extremumAngleDuringRep ?? angle)).abs();

          final repStartTime = _repStartTimeSec ?? (t - 1.0);
          final inflectionTime = _inflectionTimeSec ?? (repStartTime + 0.5);
          final durationSec = math.max(t - repStartTime, 0.4);
          final descentDuration = math.max(inflectionTime - repStartTime, 0.2);
          final ascentDuration = math.max(t - inflectionTime, 0.2);

          // Only accept repetition if duration is physically plausible (>= 0.4 sec)
          // and ROM was sufficient
          if (rom >= minimumAngleChange) {
            count++;
            final consistencyScore = (100 - (rom - 60).abs()).clamp(50.0, 98.0);
            details.add(
              RepetitionDetail(
                repNumber: count,
                durationSeconds: durationSec,
                rangeOfMotion: rom,
                tempo: durationSec,
                consistency: consistencyScore,
                phase: 'completed',
                timestampSeconds: repStartTime,
                hasVariation: rom < minimumAngleChange * 1.25,
                descentDuration: descentDuration,
                bottomDuration: 0.1,
                ascentDuration: ascentDuration,
                confidenceLevel: rom >= minimumAngleChange * 1.5 ? 'HIGH' : 'MODERATE',
              ),
            );
          }
        }
      case RepetitionPhase.completed:
        phase = RepetitionPhase.ready;
        _startAngle = angle;
        _extremumAngleDuringRep = angle;
    }
    _currentIndex++;
    return count;
  }
}

double distanceBetween(PoseLandmark first, PoseLandmark second) =>
    math.sqrt(math.pow(first.x - second.x, 2) + math.pow(first.y - second.y, 2) + math.pow(first.z - second.z, 2));

PoseLandmark midpoint(PoseLandmark first, PoseLandmark second) => PoseLandmark(
      name: 'midpoint',
      x: (first.x + second.x) / 2,
      y: (first.y + second.y) / 2,
      z: (first.z + second.z) / 2,
      confidence: math.min(first.confidence, second.confidence),
    );

double calculateRangeOfMotion(Iterable<double> values) {
  final numbers = values.where((value) => value.isFinite).toList();
  if (numbers.isEmpty) return 0;
  return numbers.reduce(math.max) - numbers.reduce(math.min);
}

double calculateAsymmetry(double left, double right) {
  final denominator = math.max((left.abs() + right.abs()) / 2, 0.0001);
  return ((left - right).abs() / denominator * 100).clamp(0, 100);
}

List<double> smooth(Iterable<double> values, {int window = 3}) {
  final numbers = values.toList();
  if (window <= 1 || numbers.length < 2) return numbers;
  return List.generate(numbers.length, (index) {
    final start = math.max(0, index - window + 1);
    final sample = numbers.sublist(start, index + 1);
    return sample.reduce((first, second) => first + second) / sample.length;
  });
}

int countRepetitions(Iterable<double> values, {double minimumChange = 15}) {
  final numbers = values.toList();
  if (numbers.length < 3) return 0;
  var count = 0;
  for (var index = 1; index < numbers.length - 1; index++) {
    final isMinimum = numbers[index] <= numbers[index - 1] && numbers[index] <= numbers[index + 1];
    final localChange = math.max((numbers[index - 1] - numbers[index]).abs(), (numbers[index + 1] - numbers[index]).abs());
    if (isMinimum && localChange >= minimumChange) count++;
  }
  return count;
}

MovementFeatures extractAngleFeatures(
  PoseSequence sequence, {
  required String first,
  required String vertex,
  required String third,
  AnalyzerThresholds thresholds = const AnalyzerThresholds(),
}) {
  if (!sequence.isSufficient || !sequence.hasLandmarks([first, vertex, third])) {
    throw const InsufficientMovementDataException();
  }
  final rawAngles = <double>[];
  final frameTimestamps = <double>[];
  final startTime = sequence.frames.first.timestamp;

  for (final frame in sequence.frames) {
    final a = frame.landmarks[first];
    final b = frame.landmarks[vertex];
    final c = frame.landmarks[third];
    if (a != null && b != null && c != null && a.isValid && b.isValid && c.isValid) {
      final angle = angleBetween(a, b, c);
      if (angle.isFinite && angle > 0) {
        rawAngles.add(angle);
        frameTimestamps.add(frame.timestamp.difference(startTime).inMilliseconds / 1000.0);
      }
    }
  }

  if (rawAngles.length < 3) throw const InsufficientMovementDataException();

  // Outlier rejection step: suppress sudden single-frame non-physical jumps
  const detector = OutlierDetector();
  final sanitized = detector.sanitizeAngleSeries(rawAngles, timestampsSec: frameTimestamps);

  // Temporal smoothing
  final filtered = smooth(sanitized);

  final duration = sequence.frames.last.timestamp.difference(sequence.frames.first.timestamp);
  final seconds = math.max(duration.inMilliseconds / 1000, 0.001);
  final mean = filtered.reduce((first, second) => first + second) / filtered.length;
  final variance = filtered.map((value) => math.pow(value - mean, 2)).reduce((first, second) => first + second) / filtered.length;

  final stateMachine = RepetitionStateMachine(
    minimumAngleChange: thresholds.minimumRepAngleChange,
    isFlexionFirst: thresholds.isFlexionFirst,
  );

  for (var i = 0; i < filtered.length; i++) {
    final t = i < frameTimestamps.length ? frameTimestamps[i] : (i * 0.033);
    stateMachine.add(filtered[i], timestampSeconds: t);
  }

  final validFrames = sequence.frames.where((frame) => [first, vertex, third].every((name) => frame.landmarks[name]?.isValid ?? false)).length;
  final repCount = stateMachine.count;
  final avgTempo = repCount > 0 ? seconds / repCount : null;
  final rom = calculateRangeOfMotion(filtered);
  final minAngle = filtered.reduce(math.min);
  final maxAngle = filtered.reduce(math.max);

  return MovementFeatures(
    angles: filtered,
    rangeOfMotion: rom,
    minAngle: minAngle,
    maxAngle: maxAngle,
    duration: duration,
    velocity: rom / seconds,
    consistency: (100 - math.sqrt(variance)).clamp(0, 100),
    repetitions: repCount,
    confidence: sequence.dataConfidence,
    validFrameRatio: validFrames / sequence.frames.length,
    tempo: avgTempo,
    repetitionDetails: stateMachine.details,
  );
}

class InsufficientMovementDataException implements Exception {
  const InsufficientMovementDataException([this.message = 'Insufficient movement data']);
  final String message;

  @override
  String toString() => message;
}