import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/models/athlete_profile.dart';
import 'package:flutter_application_1/data/services/ai_coach_service.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';

void main() {
  const coach = ExplainableMovementCoach();

  test('resolves conversational pronoun follow-ups using conversation history', () {
    const profile = AthleteProfile(name: 'Athlete');
    final session = SessionRecord(
      id: 's-1',
      athleteId: 'athlete',
      exercise: 'Squat',
      exerciseId: 'squat',
      timestamp: DateTime(2026, 1, 1),
      metrics: const MovementMetrics(
        rangeOfMotion: 92,
        symmetry: 4.2,
        consistency: 76.5,
        repetitions: 5,
        duration: Duration(seconds: 20),
        dataConfidence: 0.94,
        isMeasurementValid: true,
      ),
      analysisStatus: 'measured',
    );

    final prevSession = SessionRecord(
      id: 's-0',
      athleteId: 'athlete',
      exercise: 'Squat',
      exerciseId: 'squat',
      timestamp: DateTime(2025, 12, 30),
      metrics: const MovementMetrics(
        rangeOfMotion: 95,
        symmetry: 3.0,
        consistency: 90.0,
        repetitions: 5,
        duration: Duration(seconds: 20),
        dataConfidence: 0.95,
        isMeasurementValid: true,
      ),
      analysisStatus: 'measured',
    );

    final contextWithHistory = CoachContext(
      profile: profile,
      sessions: [session, prevSession],
      currentSession: session,
      previousSession: prevSession,
      conversationHistory: const [
        {'role': 'user', 'content': 'Why was my movement consistency lower today?'},
        {'role': 'assistant', 'content': 'Your consistency was 76.5%.'},
      ],
    );

    // Follow-up containing only "How do I fix that?"
    final followUpResponse = coach.evaluateContext('How do I fix that?', contextWithHistory);

    expect(followUpResponse.whatIObserved, contains('consistency'));
    expect(followUpResponse.howToImprove, contains('tempo'));
    expect(followUpResponse.whatItMeans, isNotEmpty);
    expect(followUpResponse.nextAttemptCue, isNotEmpty);
  });

  test('formats 5-section structured markdown correctly', () {
    const profile = AthleteProfile(name: 'Athlete');
    final session = SessionRecord(
      id: 's-1',
      athleteId: 'athlete',
      exercise: 'Squat',
      exerciseId: 'squat',
      timestamp: DateTime(2026, 1, 1),
      metrics: const MovementMetrics(
        rangeOfMotion: 90,
        symmetry: 5.0,
        consistency: 91.0,
        repetitions: 6,
        duration: Duration(seconds: 25),
        dataConfidence: 0.96,
        isMeasurementValid: true,
      ),
      analysisStatus: 'measured',
    );

    final context = CoachContext(
      profile: profile,
      sessions: [session],
      currentSession: session,
    );

    final response = coach.evaluateContext('Explain my range of motion', context);
    final markdown = response.toStructuredMarkdown();

    expect(markdown, contains('### What I Observed'));
    expect(markdown, contains('### What It Means'));
    expect(markdown, contains('### How to Improve'));
    expect(markdown, contains('### Next Attempt'));
    expect(markdown, contains('### Data Limitations'));
  });

  test('AiSafetyFilter intercepts clinical diagnosis and applies non-diagnostic policy', () {
    final filter = AiSafetyFilter();
    const unsafeResponse = AiCoachResponse(
      summary: 'You have a medical diagnosis of ACL tear and are medically cleared.',
      observations: ['ACL damage detected'],
      trainingSuggestions: ['Cure it with squats'],
      professionalReviewQuestions: [],
      limitations: [],
    );

    final safeResponse = filter.validate(unsafeResponse);
    expect(safeResponse.summary, contains('withheld'));
    expect(safeResponse.summary, contains('licensed physical therapist'));
    expect(safeResponse.limitations, contains('Movement-analysis support, not medical diagnosis.'));
  });

  test('offline agent explains measured ROM and addresses the athlete by name', () {
    final session = SessionRecord(
      id: 's-1',
      athleteId: 'athlete',
      exercise: 'Squat',
      exerciseId: 'squat',
      timestamp: DateTime(2026, 1, 1),
      metrics: const MovementMetrics(
        rangeOfMotion: 92,
        symmetry: null,
        consistency: 76.5,
        repetitions: 5,
        duration: Duration(seconds: 20),
        dataConfidence: 0.94,
        isMeasurementValid: true,
      ),
      analysisStatus: 'measured',
    );
    final context = CoachContext(
      profile: const AthleteProfile(name: 'Maya'),
      sessions: [session],
      currentSession: session,
    );

    final response = const OfflineMovementCoachAgent().answer(
      'How is my ROM calculated?',
      context,
    );

    expect(response.summary, contains('Hi Maya'));
    expect(response.whatIObserved, contains('92.0°'));
    expect(response.whatItMeans, contains('maximum observed joint angle minus minimum'));
    expect(response.evidenceUsed, contains('Squat: 5 repetitions'));
  });

  test('offline agent gives Tamil food guidance and localized headings', () {
    final response = const OfflineMovementCoachAgent().answer(
      'உணவு பற்றி சொல்லுங்கள்',
      const CoachContext(
        profile: AthleteProfile(name: 'Maya'),
        sessions: [],
      ),
      language: CoachLanguage.tamil,
    );
    final formatted = response.toStructuredMarkdown(language: CoachLanguage.tamil);

    expect(response.summary, contains('வணக்கம் Maya'));
    expect(response.whatItMeans, contains('காய்கறி'));
    expect(formatted, contains('### நான் கவனித்தது'));
    expect(formatted, contains('### தரவு வரம்புகள்'));
  });
}
