import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/models/session_report.dart';
import 'package:flutter_application_1/domain/services/trend_analysis_service.dart';

void main() {
  SessionRecord session(String id, DateTime date, double rom, {double? symmetry}) => SessionRecord(id: id, athleteId: 'a', exercise: 'Squat', exerciseId: 'squat', timestamp: date, metrics: MovementMetrics(rangeOfMotion: rom, symmetry: symmetry, consistency: rom, duration: const Duration(seconds: 20), repetitions: 2, dataConfidence: .8, validFrameRatio: .9));

  test('filters by exercise and ignores null metric values', () {
    final trend = TrendAnalysisService().analyze([session('1', DateTime(2026, 1), 20), session('2', DateTime(2026, 2), 30, symmetry: 8), session('3', DateTime(2026, 3), 40)], exerciseId: 'squat');
    expect(trend.rom.points.length, 3);
    expect(trend.symmetry.points.length, 1);
    expect(trend.rom.direction, TrendDirection.improving);
  });

  test('round-trips a structured session report', () {
    final report = SessionReport(athleteId: 'a', exercise: 'Squat', session: session('1', DateTime(2026), 20), historicalComparison: const {'romChange': 5}, observations: const ['Observed ROM increased.'], limitations: const [], professionalReviewNote: 'Review with a qualified professional.');
    final restored = SessionReport.fromJson(report.toJson());
    expect(restored.session.id, '1');
    expect(restored.historicalComparison['romChange'], 5);
  });

  test('requires two distinct sessions for comparison', () {
    final trend = TrendAnalysisService().analyze([session('1', DateTime(2026), 20)]);
    expect(trend.comparison.hasEnoughData, isFalse);
    expect(trend.rom.direction, TrendDirection.insufficientData);
  });
}