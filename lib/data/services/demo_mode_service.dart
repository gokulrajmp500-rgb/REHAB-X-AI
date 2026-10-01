import '../../domain/models/pose_models.dart';

class DemoSession {
  const DemoSession({required this.exercise, required this.metrics});
  final String exercise;
  final MovementMetrics metrics;
  String get label => 'DEMO DATA';
}

class DemoModeService {
  const DemoModeService();

  DemoSession createPreview() => const DemoSession(
    exercise: 'Squat',
    metrics: MovementMetrics(rangeOfMotion: 0, symmetry: null, consistency: 0, duration: Duration.zero, repetitions: 0),
  );

  bool canWriteToRealHistory(SessionRecord session) => !session.isDemo;
}