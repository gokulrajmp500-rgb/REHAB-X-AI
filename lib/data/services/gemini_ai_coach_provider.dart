import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_coach_service.dart';

class GeminiAiCoachProvider implements AiCoachProvider {
  GeminiAiCoachProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String _baseUrl = const String.fromEnvironment(
    'REHAB_X_API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  AiProviderStatus _status = AiProviderStatus.unavailable;

  @override
  AiProviderStatus get status => _status;

  @override
  Future<void> initialize() async {
    try {
      final response = await _client.get(Uri.parse('$_baseUrl/api/ai/status'));
      if (response.statusCode != 200) {
        _status = AiProviderStatus.unavailable;
        return;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      _status = payload['configured'] == true
          ? AiProviderStatus.ready
          : AiProviderStatus.unavailable;
    } catch (_) {
      _status = AiProviderStatus.unavailable;
    }
  }

  @override
  Future<AiCoachResponse> generateCoachResponse(
    String question,
    CoachContext context,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/ai/chat'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'question': question, 'context': context.toJson()}),
    );
    if (response.statusCode != 200) {
      _status = AiProviderStatus.error;
      throw Exception('Gemini backend returned ${response.statusCode}.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    _status = AiProviderStatus.ready;
    return AiCoachResponse(
      summary: payload['summary'] as String? ?? 'Gemini returned no summary.',
      observations: _strings(payload['observations']),
      trainingSuggestions: _strings(payload['trainingSuggestions']),
      professionalReviewQuestions: _strings(payload['professionalReviewQuestions']),
      limitations: _strings(payload['limitations']),
      evidenceUsed: _strings(payload['evidenceUsed']),
      basedOn: payload['basedOn'] as String? ?? 'Gemini analysis',
    );
  }

  List<String> _strings(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  @override
  Future<void> dispose() async => _client.close();
}
