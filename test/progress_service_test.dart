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
      SessionRecord(
        id: '2',
        athleteId: 'a',
        exercise: 'Squat',
        timestamp: DateTime(2026, 2),
        metrics: const MovementMetrics(
          rangeOfMotion: 40,
          symmetry: null,
          consistency: 70,
          duration: Duration.zero,
          repetitions: 2,
        ),
      ),
      SessionRecord(
        id: '1',
        athleteId: 'a',
        exercise: 'Squat',
        timestamp: DateTime(2026, 1),
        metrics: const MovementMetrics(
          rangeOfMotion: 20,
          symmetry: null,
          consistency: 60,
          duration: Duration.zero,
          repetitions: 1,
        ),
      ),
    ];
    final summary = ProgressService().summarize(sessions);
    expect(summary.first?.id, '1');
    expect(summary.latest?.id, '2');
    expect(summary.trend(summary.rom), TrendStatus.improving);
  });

  test(
    'verified session filter excludes demo, simulation, and invalid data',
    () {
      final real = SessionRecord(
        id: 'real',
        athleteId: 'a',
        exercise: 'Squat',
        timestamp: DateTime(2026),
        metrics: const MovementMetrics(
          rangeOfMotion: 35,
          symmetry: null,
          consistency: 80,
          duration: Duration(seconds: 20),
          repetitions: 5,
          dataConfidence: .9,
          validFrameRatio: .9,
        ),
      );
      final demo = SessionRecord(
        id: 'demo',
        athleteId: 'a',
        exercise: 'Squat',
        timestamp: DateTime(2026),
        metrics: real.metrics,
        isDemo: true,
      );
      final simulation = SessionRecord(
        id: 'simulation',
        athleteId: 'a',
        exercise: 'Squat',
        timestamp: DateTime(2026),
        metrics: real.metrics,
        sourceMode: 'simulation',
      );
      final invalid = SessionRecord(
        id: 'invalid',
        athleteId: 'a',
        exercise: 'Squat',
        timestamp: DateTime(2026),
        metrics: const MovementMetrics(
          rangeOfMotion: 0,
          symmetry: null,
          consistency: 0,
          duration: Duration.zero,
          repetitions: 0,
          isMeasurementValid: false,
        ),
      );
      final incomplete = SessionRecord(
        id: 'incomplete',
        athleteId: 'a',
        exercise: 'Squat',
        timestamp: DateTime(2026),
        metrics: const MovementMetrics(
          rangeOfMotion: 25,
          symmetry: null,
          consistency: 75,
          duration: Duration(seconds: 20),
          repetitions: 4,
          dataConfidence: 0,
          validFrameRatio: 0.8,
        ),
      );
      final syntheticVideo = SessionRecord(
        id: 'synthetic-video',
        athleteId: 'a',
        exercise: 'Squat',
        timestamp: DateTime(2026),
        metrics: real.metrics,
        modelVersion: 'mlkit-video-pipeline',
        sourceMode: 'video',
      );
      final legacyMeasured = SessionRecord(
        id: 'legacy-measured',
        athleteId: 'a',
        exercise: 'Squat',
        timestamp: DateTime(2026),
        metrics: real.metrics,
        analysisStatus: 'unknown',
      );

      expect(
        verifiedMovementSessions([
          demo,
          simulation,
          invalid,
          incomplete,
          syntheticVideo,
          legacyMeasured,
          real,
        ]).map((s) => s.id),
        unorderedEquals(['legacy-measured', 'real']),
      );
    },
  );
}
