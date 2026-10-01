import 'dart:math' as math;

import '../../domain/models/pose_models.dart';

/// 1D One Euro Filter implementation.
/// Reference: Casiez, G., Roussel, N. and Vogel, F. (2012).
/// "1€ Filter: A Simple Speed-based Low-pass Filter for Noisy Input in Human-Computer Interaction"
class OneEuroFilter1D {
  OneEuroFilter1D({
    this.minCutoff = 1.0,
    this.beta = 0.007,
    this.dCutoff = 1.0,
  });

  final double minCutoff;
  final double beta;
  final double dCutoff;

  double? _xPrev;
  double? _dxPrev;
  double? _tPrev;

  double _alpha(double cutoff, double te) {
    final tau = 1.0 / (2.0 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / te);
  }

  double filter(double x, double timestampSec) {
    if (_tPrev == null) {
      _xPrev = x;
      _dxPrev = 0.0;
      _tPrev = timestampSec;
      return x;
    }

    final te = timestampSec - _tPrev!;
    // Prevent division by zero or negative timestamps
    if (te <= 1e-5) {
      return _xPrev ?? x;
    }

    // Estimate derivative (speed)
    final dx = (x - (_xPrev ?? x)) / te;
    final aD = _alpha(dCutoff, te);
    final dxHat = aD * dx + (1.0 - aD) * (_dxPrev ?? 0.0);

    // Adaptive cutoff frequency based on movement speed
    final cutoff = minCutoff + beta * dxHat.abs();
    final a = _alpha(cutoff, te);
    final xHat = a * x + (1.0 - a) * (_xPrev ?? x);

    _xPrev = xHat;
    _dxPrev = dxHat;
    _tPrev = timestampSec;

    return xHat;
  }

  void reset() {
    _xPrev = null;
    _dxPrev = null;
    _tPrev = null;
  }
}

/// 2D Landmark temporal filter maintaining separate X and Y One-Euro filters.
class LandmarkTemporalFilter {
  LandmarkTemporalFilter({
    this.minCutoff = 1.2,
    this.beta = 0.01,
    this.dCutoff = 1.0,
  });

  final double minCutoff;
  final double beta;
  final double dCutoff;

  final Map<String, OneEuroFilter1D> _filtersX = {};
  final Map<String, OneEuroFilter1D> _filtersY = {};

  /// Filters a complete [PoseFrame], returning a new [PoseFrame] with filtered landmark
  /// coordinates while preserving the original raw coordinates in the landmark model.
  PoseFrame filterFrame(PoseFrame frame) {
    final timestampSec = frame.timestamp.millisecondsSinceEpoch / 1000.0;
    final filteredLandmarks = <String, PoseLandmark>{};

    for (final entry in frame.landmarks.entries) {
      final key = entry.key;
      final raw = entry.value;

      if (!raw.isValid) {
        filteredLandmarks[key] = raw;
        continue;
      }

      final filterX = _filtersX.putIfAbsent(
        key,
        () => OneEuroFilter1D(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff),
      );
      final filterY = _filtersY.putIfAbsent(
        key,
        () => OneEuroFilter1D(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff),
      );

      final smoothX = filterX.filter(raw.x, timestampSec);
      final smoothY = filterY.filter(raw.y, timestampSec);

      filteredLandmarks[key] = PoseLandmark(
        name: raw.name,
        x: smoothX,
        y: smoothY,
        z: raw.z,
        confidence: raw.confidence,
        rawX: raw.rawX ?? raw.x,
        rawY: raw.rawY ?? raw.y,
        isFiltered: true,
      );
    }

    return PoseFrame(
      timestamp: frame.timestamp,
      landmarks: filteredLandmarks,
      imageWidth: frame.imageWidth,
      imageHeight: frame.imageHeight,
      personCount: frame.personCount,
      isMultiPerson: frame.isMultiPerson,
    );
  }

  void reset() {
    _filtersX.clear();
    _filtersY.clear();
  }
}

