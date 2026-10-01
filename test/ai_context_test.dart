import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/models/athlete_profile.dart';
import 'package:flutter_application_1/data/services/ai_coach_service.dart';

void main() {
  test('unavailable AI provider returns no fabricated interpretation', () async {
    final service = UnavailableAiCoachService();
    final response = await service.structuredAnswer('Explain my metrics', const CoachContext(profile: AthleteProfile(name: 'A'), sessions: []));
    expect(service.isConfigured, isFalse);
    expect(response.summary, contains('unavailable'));
    expect(response.trainingSuggestions, isEmpty);
  });

  test('local coach answers different topics differently', () {
    const context = CoachContext(profile: AthleteProfile(name: 'A'), sessions: []);
    const coach = ExplainableMovementCoach();

    final squat = coach.evaluateContext('How should I improve my squat depth?', context);
    final recovery = coach.evaluateContext('How should I recover after training?', context);
    final camera = coach.evaluateContext('How do I record a session?', context);
    final range = coach.evaluateContext('What did my range-of-motion trend show?', context);
    final help = coach.evaluateContext('I want help', context);

    expect(squat.summary, isNot(equals(recovery.summary)));
    expect(recovery.summary, isNot(equals(camera.summary)));
    expect(range.summary, isNot(equals(help.summary)));
    expect(squat.summary, contains('squat'));
    expect(recovery.summary, contains('recovery'));
    expect(camera.summary, contains('session'));
    expect(range.summary, contains('range-of-motion'));
    expect(help.summary, contains('help'));
  });
}