import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/services/movement_quality_evaluator.dart';

void main() {
  const evaluator = MovementQualityEvaluator();

  test('reports strong consistency and data quality from measured metrics', () {
    const metrics = MovementMetrics(rangeOfMotion: 45, symmetry: 10, consistency: 88, duration: Duration(seconds: 20), repetitions: 4, velocity: 0.8, dataConfidence: 0.9);
    final report = evaluator.evaluate(metrics, validFrameRatio: 0.95);
    expect(report.overall, QualityStatus.strong);
    expect(report.observations, contains('Movement was consistent across the available frames.'));
  });

  test('reports limitations when valid data is insufficient', () {
    const metrics = MovementMetrics(rangeOfMotion: 0, symmetry: null, consistency: 0, duration: Duration.zero, repetitions: 0);
    final report = evaluator.evaluate(metrics, validFrameRatio: 0.3);
    expect(report.overall, QualityStatus.attention);
    expect(report.limitations, isNotEmpty);
  });

  test('stores quality and limitations in a session record', () {
    final session = SessionRecord(id: 's', athleteId: 'a', exercise: 'Squat', timestamp: DateTime(2026), metrics: const MovementMetrics(rangeOfMotion: 20, symmetry: null, consistency: 75, duration: Duration(seconds: 1), repetitions: 1), qualityLabel: 'strong', limitations: const ['none']);
    final restored = SessionRecord.fromJson(session.toJson());
    expect(restored.qualityLabel, 'strong');
    expect(restored.limitations, ['none']);
  });
}