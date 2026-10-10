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
  String _statusMessage = 'AI backend has not been checked yet.';

  @override
  AiProviderStatus get status => _status;

  String get statusMessage => _statusMessage;

  @override
  Future<void> initialize() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/ai/status'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        _status = AiProviderStatus.unavailable;
        _statusMessage =
            'AI backend returned HTTP ${response.statusCode} at $_baseUrl.';
        return;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (payload['configured'] == true) {
        _status = AiProviderStatus.ready;
        _statusMessage = 'Gemini is connected.';
      } else {
        _status = AiProviderStatus.unavailable;
        _statusMessage =
            'Backend is reachable, but GEMINI_API_KEY is not configured on the backend.';
      }
    } on Object catch (error) {
      _status = AiProviderStatus.unavailable;
      _statusMessage =
          'Cannot reach AI backend at $_baseUrl. Start the backend and check its URL. $error';
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
      String detail = '';
      try {
        final payload = jsonDecode(response.body);
        if (payload is Map) detail = payload['detail']?.toString() ?? '';
      } on FormatException {
        detail = response.body;
      }
      _statusMessage = detail.isEmpty
          ? 'Gemini backend returned HTTP ${response.statusCode}.'
          : detail;
      throw Exception(_statusMessage);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    _status = AiProviderStatus.ready;
    _statusMessage = 'Gemini is connected.';
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
