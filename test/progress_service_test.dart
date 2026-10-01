import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/services/progress_service.dart';

void main() {
  test('returns insufficient data without inventing a trend', () {
    final summary = ProgressService().summarize(const []);
    expect(summary.trend(summary.rom), TrendStatus.insufficientData);
    expect(summary.first, isNull);
  });

  test('compares ordered first and latest sessions', () {
    final sessions = [
      SessionRecord(id: '2', athleteId: 'a', exercise: 'Squat', timestamp: DateTime(2026, 2), metrics: const MovementMetrics(rangeOfMotion: 40, symmetry: null, consistency: 70, duration: Duration.zero, repetitions: 2)),
      SessionRecord(id: '1', athleteId: 'a', exercise: 'Squat', timestamp: DateTime(2026, 1), metrics: const MovementMetrics(rangeOfMotion: 20, symmetry: null, consistency: 60, duration: Duration.zero, repetitions: 1)),
    ];
    final summary = ProgressService().summarize(sessions);
    expect(summary.first?.id, '1');
    expect(summary.latest?.id, '2');
    expect(summary.trend(summary.rom), TrendStatus.improving);
  });
}