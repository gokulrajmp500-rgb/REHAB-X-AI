import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/models/athlete_profile.dart';
import 'package:flutter_application_1/data/services/ai_coach_service.dart';
import 'package:flutter_application_1/data/services/gemini_ai_coach_provider.dart';

void main() {
  test('Gemini provider sends conversation history and parses freeform summary', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/api/ai/status')) {
        return http.Response(jsonEncode({'configured': true}), 200);
      }
      return http.Response(
        jsonEncode({
          'summary': 'A clear answer to the athlete\'s open-ended question.',
          'observations': <String>[],
          'trainingSuggestions': <String>[],
          'professionalReviewQuestions': <String>[],
          'limitations': <String>[],
          'evidenceUsed': <String>[],
          'basedOn': 'Gemini conversation',
        }),
        200,
      );
    });
    final provider = GeminiAiCoachProvider(client: client);
    const history = [
      {'role': 'user', 'content': 'How does recovery work?'},
      {'role': 'assistant', 'content': 'Recovery includes rest and adaptation.'},
      {'role': 'user', 'content': 'Can you explain that simply?'},
    ];

    await provider.initialize();
    final response = await provider.generateCoachResponse(
      'Can you explain that simply?',
      const CoachContext(
        profile: AthleteProfile(name: 'Maya'),
        sessions: [],
        conversationHistory: history,
        responseLanguage: 'Tamil',
      ),
    );

    final chatRequest = requests.last;
    final body = jsonDecode(chatRequest.body) as Map<String, dynamic>;
    final context = body['context'] as Map<String, dynamic>;
    expect(chatRequest.url.path, endsWith('/api/ai/chat'));
    expect(context['conversationHistory'], history);
    expect(context['responseLanguage'], 'Tamil');
    expect(response.summary, contains('open-ended question'));
    expect(response.basedOn, 'Gemini conversation');
    await provider.dispose();
  });

  test('provider-backed service blocks unsupported medical output', () async {
    final service = ProviderBackedAiCoachService(_UnsafeProvider());
    final response = await service.structuredAnswer('question', const CoachContext(profile: AthleteProfile(name: 'A'), sessions: []));
    expect(response.summary, contains('withheld'));
    expect(response.limitations, contains('Movement-analysis support, not medical diagnosis.'));
  });
}

class _UnsafeProvider implements AiCoachProvider {
  @override AiProviderStatus get status => AiProviderStatus.ready;
  @override Future<void> initialize() async {}
  @override Future<void> dispose() async {}
  @override Future<AiCoachResponse> generateCoachResponse(String question, CoachContext context) async => const AiCoachResponse(summary: 'You are medically cleared.', observations: [], trainingSuggestions: [], professionalReviewQuestions: [], limitations: []);
}