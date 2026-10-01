/// Real-world distance calibration helper.
///
/// Prevents fabricating centimeters from raw 2D pixel coordinates.
/// Uncalibrated measurements remain strictly relative, while calibrated measurements
/// require an explicit scale factor and are clearly labeled as estimates.
class DistanceCalibration {
  const DistanceCalibration({
    this.isCalibrated = false,
    this.pixelsPerCentimeter,
    this.calibrationReference,
    this.calibrationDate,
  });

  final bool isCalibrated;
  final double? pixelsPerCentimeter;
  final String? calibrationReference;
  final DateTime? calibrationDate;

  /// Returns a formatted distance string based on calibration status.
  /// If uncalibrated, returns a relative index or explicit limitation note.
  String formatDistance(double pixelDistance) {
    if (!isCalibrated || pixelsPerCentimeter == null || pixelsPerCentimeter! <= 0) {
      return 'Relative index: ${(pixelDistance / 10).toStringAsFixed(1)} (uncalibrated)';
    }

    final cm = pixelDistance / pixelsPerCentimeter!;
    return '${cm.toStringAsFixed(1)} cm (Camera-calibrated estimate)';
  }

  /// Estimates distance in cm only if calibration is established.
  /// Returns null if uncalibrated.
  double? estimateCm(double pixelDistance) {
    if (!isCalibrated || pixelsPerCentimeter == null || pixelsPerCentimeter! <= 0) {
      return null;
    }
    return pixelDistance / pixelsPerCentimeter!;
  }

  /// Calibrates using athlete height in centimeters and full-body pixel height (vertex to ankle).
  factory DistanceCalibration.fromAthleteHeight({
    required double athleteHeightCm,
    required double bodyPixelHeight,
  }) {
    if (athleteHeightCm <= 50 || athleteHeightCm >= 250 || bodyPixelHeight <= 50) {
      return const DistanceCalibration(isCalibrated: false);
    }

    // Estimate scale under controlled standing assumption
    final ppc = bodyPixelHeight / athleteHeightCm;
    return DistanceCalibration(
      isCalibrated: true,
      pixelsPerCentimeter: ppc,
      calibrationReference: 'Athlete height (${athleteHeightCm.toStringAsFixed(0)} cm)',
      calibrationDate: DateTime.now(),
    );
  }

  /// Calibrates using a reference object of known width or height.
  factory DistanceCalibration.fromReferenceObject({
    required double knownDimensionCm,
    required double objectPixelDimension,
    required String objectName,
  }) {
    if (knownDimensionCm <= 0 || objectPixelDimension <= 0) {
      return const DistanceCalibration(isCalibrated: false);
    }
    final ppc = objectPixelDimension / knownDimensionCm;
    return DistanceCalibration(
      isCalibrated: true,
      pixelsPerCentimeter: ppc,
      calibrationReference: 'Reference object: $objectName ($knownDimensionCm cm)',
      calibrationDate: DateTime.now(),
    );
  }
}

