import 'dart:math' as math;

import '../models/pose_models.dart';
import 'movement_features.dart';

export 'movement_features.dart' show InsufficientMovementDataException;

class MovementAnalysisService {
  MovementMetrics analyze(PoseSequence sequence) {
    if (!sequence.isSufficient) {
      throw const InsufficientMovementDataException();
    }
    final duration = sequence.frames.last.timestamp.difference(sequence.frames.first.timestamp);
    final angles = <double>[];
    for (final frame in sequence.frames) {
      final hip = frame.landmarks['hip'];
      final knee = frame.landmarks['knee'];
      final ankle = frame.landmarks['ankle'];
      if (hip != null && knee != null && ankle != null) {
        angles.add(angleBetween(hip, knee, ankle));
      }
    }
    if (angles.isEmpty) throw const InsufficientMovementDataException();
    final range = angles.reduce((a, b) => a > b ? a : b) - angles.reduce((a, b) => a < b ? a : b);
    return MovementMetrics(rangeOfMotion: range, symmetry: null, consistency: _consistency(angles), duration: duration, repetitions: _countRepetitions(angles));
  }

  double _consistency(List<double> values) {
    if (values.length < 2) return 100;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((value) => (value - mean) * (value - mean)).reduce((a, b) => a + b) / values.length;
    return (100 - math.sqrt(variance)).clamp(0, 100);
  }

  int _countRepetitions(List<double> angles) {
    var repetitions = 0;
    for (var index = 1; index < angles.length - 1; index++) {
      if (angles[index] < angles[index - 1] && angles[index] <= angles[index + 1]) repetitions++;
    }
    return repetitions;
  }
}

