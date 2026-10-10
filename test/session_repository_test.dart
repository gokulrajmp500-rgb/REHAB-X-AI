import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/data/repositories/session_repository.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('persists, reads, updates, and deletes sessions', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalSessionRepository(await SharedPreferences.getInstance());
    final session = SessionRecord(id: 'session-1', athleteId: 'athlete-1', exercise: 'Squat', timestamp: DateTime(2026), metrics: const MovementMetrics(rangeOfMotion: 42, symmetry: null, consistency: 91, duration: Duration(seconds: 30), repetitions: 5));

    await repository.create(session);
    expect((await repository.readAll('athlete-1')).single.exercise, 'Squat');
    await repository.update(SessionRecord(id: session.id, athleteId: session.athleteId, exercise: 'Lunge', timestamp: session.timestamp, metrics: session.metrics));
    expect((await repository.read('session-1'))?.exercise, 'Lunge');
    await repository.delete('session-1');
    expect(await repository.read('session-1'), isNull);
  });

  test('reports corrupted persisted session payloads', () async {
    SharedPreferences.setMockInitialValues({'movement_sessions': '{not-json'});
    final repository = LocalSessionRepository(await SharedPreferences.getInstance());
    await expectLater(
      repository.readAll('athlete-1'),
      throwsFormatException,
    );
  });
}