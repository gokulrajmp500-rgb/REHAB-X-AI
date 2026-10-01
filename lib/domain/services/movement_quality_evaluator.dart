import '../models/pose_models.dart';

enum QualityStatus { strong, attention, insufficientData }

class MovementQualityReport {
  const MovementQualityReport({required this.overall, required this.consistency, required this.symmetry, required this.rangeOfMotion, required this.dataQuality, required this.movementControl, required this.observations, required this.limitations});
  final QualityStatus overall;
  final QualityStatus consistency;
  final QualityStatus symmetry;
  final QualityStatus rangeOfMotion;
  final QualityStatus dataQuality;
  final QualityStatus movementControl;
  final List<String> observations;
  final List<String> limitations;
}

class MovementQualityEvaluator {
  const MovementQualityEvaluator({this.minimumConfidence = 0.65, this.minimumConsistency = 70, this.maximumAsymmetry = 20});
  final double minimumConfidence;
  final double minimumConsistency;
  final double maximumAsymmetry;

  MovementQualityReport evaluate(MovementMetrics metrics, {double? validFrameRatio, double? asymmetry}) {
    final limitations = <String>[];
    final observations = <String>[];
    final dataQuality = metrics.dataConfidence >= minimumConfidence && (validFrameRatio == null || validFrameRatio >= 0.7) ? QualityStatus.strong : QualityStatus.attention;
    if (metrics.dataConfidence == 0 || (validFrameRatio != null && validFrameRatio < 0.5)) {
      limitations.add('Insufficient valid frames for reliable comparison.');
    } else if (dataQuality == QualityStatus.attention) {
      limitations.add('Repeat the assessment with improved full-body visibility.');
    }
    final consistency = metrics.consistency >= minimumConsistency ? QualityStatus.strong : QualityStatus.attention;
    final symmetry = asymmetry == null ? (metrics.symmetry == null ? QualityStatus.insufficientData : _symmetry(metrics.symmetry!)) : _symmetry(asymmetry);
    final range = metrics.rangeOfMotion > 0 ? QualityStatus.strong : QualityStatus.insufficientData;
    final control = metrics.velocity == null || metrics.velocity! <= 1.5 ? QualityStatus.strong : QualityStatus.attention;
    if (consistency == QualityStatus.strong) observations.add('Movement was consistent across the available frames.');
    if (consistency == QualityStatus.attention) observations.add('Movement consistency varied during the session.');
    if (symmetry == QualityStatus.attention) observations.add('Left/right movement showed measurable asymmetry.');
    if (range == QualityStatus.strong) observations.add('A measurable range of motion was recorded.');
    if (control == QualityStatus.attention) observations.add('Movement speed varied; maintain controlled movement.');
    final statuses = [dataQuality, consistency, symmetry, range, control];
    final overall = limitations.isNotEmpty ? QualityStatus.attention : statuses.contains(QualityStatus.attention) ? QualityStatus.attention : statuses.contains(QualityStatus.insufficientData) ? QualityStatus.insufficientData : QualityStatus.strong;
    return MovementQualityReport(overall: overall, consistency: consistency, symmetry: symmetry, rangeOfMotion: range, dataQuality: dataQuality, movementControl: control, observations: observations, limitations: limitations);
  }

  QualityStatus _symmetry(double value) => value <= maximumAsymmetry ? QualityStatus.strong : QualityStatus.attention;
}