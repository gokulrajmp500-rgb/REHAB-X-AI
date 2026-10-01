import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/services/video_analysis_service.dart';
import 'package:flutter_application_1/domain/services/exercise_analyzers.dart';

void main() {
  group('VideoAnalysisService', () {
    const service = VideoAnalysisService();

    test('empty path throws VideoAnalysisException', () async {
      expect(
        () => service.analyzeVideo(
          videoPath: '',
          exerciseId: 'squat',
          exerciseName: 'Squat',
          athleteId: 'athlete',
          analyzer: const SquatAnalyzer(),
        ),
        throwsA(isA<VideoAnalysisException>()),
      );
    });

    test('simulated video processes frames, emits progress, and returns valid result', () async {
      final progressUpdates = <double>[];

      final result = await service.analyzeVideo(
        videoPath: 'sample_squat_recording.mp4',
        exerciseId: 'squat',
        exerciseName: 'Squat',
        athleteId: 'athlete_test',
        analyzer: const SquatAnalyzer(),
        onProgress: (p) => progressUpdates.add(p.percentage),
      );

      expect(progressUpdates, isNotEmpty);
      expect(result.totalFrames, 120);
      expect(result.validFrames, greaterThan(50));
      expect(result.session.exerciseId, 'squat');
      expect(result.session.sourceMode, 'video');
      expect(result.session.metrics.rangeOfMotion, greaterThan(0));
    });
  });
}
