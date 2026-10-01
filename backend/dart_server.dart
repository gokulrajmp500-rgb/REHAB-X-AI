import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8000);

  await for (final request in server) {
    _addCorsHeaders(request.response);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      continue;
    }

    try {
      if (request.method == 'GET' && request.uri.path == '/api/ai/status') {
        await _writeJson(request.response, {
          'configured':
              Platform.environment['GEMINI_API_KEY']?.isNotEmpty == true,
          'provider': 'gemini',
          'model': Platform.environment['GEMINI_MODEL'] ?? 'gemini-2.5-flash',
        });
      } else if (request.method == 'POST' &&
          request.uri.path == '/api/ai/chat') {
        await _handleChat(request);
      } else if (request.method == 'GET' && request.uri.path == '/health') {
        await _writeJson(request.response, {
          'status': 'ok',
          'service': 'rehab-x-ai',
        });
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await _writeJson(request.response, {'detail': 'Not found'});
      }
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      await _writeJson(request.response, {'detail': error.toString()});
    }
  }
}

Future<void> _handleChat(HttpRequest request) async {
  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    request.response.statusCode = HttpStatus.serviceUnavailable;
    await _writeJson(request.response, {
      'detail': 'GEMINI_API_KEY is not configured on the backend.',
    });
    return;
  }

  final body =
      jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;
  final question = body['question']?.toString() ?? '';
  final context = body['context'] ?? const <String, dynamic>{};
  if (question.trim().isEmpty) {
    request.response.statusCode = HttpStatus.badRequest;
    await _writeJson(request.response, {'detail': 'A question is required.'});
    return;
  }
  final model = Platform.environment['GEMINI_MODEL'] ?? 'gemini-2.5-flash';
  final prompt = _coachPrompt(context);
  final client = HttpClient();

  try {
    final outbound = await client.postUrl(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      ),
    );
    outbound.headers.contentType = ContentType.json;
    outbound.headers.set('x-goog-api-key', apiKey);
    outbound.write(
      jsonEncode({
        'contents': [
          ..._conversationContents(question, context),
        ],
        'systemInstruction': {
          'parts': [
            {'text': prompt},
          ],
        },
        'generationConfig': {
          'temperature': 0.55,
          'responseMimeType': 'application/json',
        },
      }),
    );
    final response = await outbound.close();
    final responseText = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      request.response.statusCode = HttpStatus.badGateway;
      await _writeJson(request.response, {
        'detail': 'Gemini request failed: $responseText',
      });
      return;
    }
    final providerPayload = jsonDecode(responseText) as Map<String, dynamic>;
    final modelText =
        (((providerPayload['candidates'] as List).first
                    as Map<String, dynamic>)['content']
                as Map<String, dynamic>)['parts']
            as List;
    final text = (modelText.first as Map<String, dynamic>)['text'] as String;
    await _writeJson(request.response, _parseModelResponse(text));
  } finally {
    client.close();
  }
}

String _coachPrompt(Object context) {
  final Map<String, dynamic> contextWithoutHistory = context is Map
      ? Map<String, dynamic>.from(context)
      : <String, dynamic>{};
  contextWithoutHistory.remove('conversationHistory');
  return '''You are Mitra, REHAB-X AI's helpful, conversational assistant.
Answer the athlete's actual question directly and naturally, like a capable general-purpose
chat assistant. You may answer general questions about exercise, movement, recovery, nutrition
basics, and everyday topics; do not force every answer into a movement-analysis template.
Use the supplied profile and movement data only when relevant. Never invent measurements or
claim to have observed data that is not provided. If a personal measurement is missing, say so.
When a response language is provided in context, answer in that language. Do not diagnose medical
conditions, prescribe medication, or claim medical clearance. For pain,
injury, or urgent symptoms, give cautious general information and recommend an appropriate
licensed healthcare professional. Match the athlete's language and keep the answer useful and
clear, using detail appropriate to the question.
Return valid JSON with these string/list fields. Put the complete conversational answer in
summary; use the other fields only for relevant observations and concise optional guidance:
summary, observations, trainingSuggestions, professionalReviewQuestions, limitations,
evidenceUsed, basedOn.

Verified app context (not a restriction on general questions):
${jsonEncode(contextWithoutHistory)}''';
}

List<Map<String, Object>> _conversationContents(
  String question,
  Object context,
) {
  final history = context is Map ? context['conversationHistory'] : null;
  final turns = <Map<String, Object>>[];
  if (history is List) {
    for (final item in history) {
      if (item is! Map) continue;
      final role = item['role'];
      final content = item['content'];
      if ((role != 'user' && role != 'assistant') || content is! String) {
        continue;
      }
      final trimmedContent = content.trim();
      if (trimmedContent.isEmpty) continue;
      turns.add({
        'role': role == 'assistant' ? 'model' : 'user',
        'parts': [
          {
            'text': trimmedContent.length > 4000
                ? trimmedContent.substring(0, 4000)
                : trimmedContent,
          },
        ],
      });
    }
  }

  if (turns.length > 12) turns.removeRange(0, turns.length - 12);
  while (turns.isNotEmpty && turns.first['role'] == 'model') {
    turns.removeAt(0);
  }
  final lastParts = turns.isNotEmpty ? turns.last['parts'] as List : const [];
  final lastContent = lastParts.isNotEmpty
      ? (lastParts.first as Map)['text']
      : null;
  if (turns.isEmpty || turns.last['role'] != 'user' || lastContent != question) {
    turns.add({
      'role': 'user',
      'parts': [
        {
          'text': question.length > 4000
              ? question.substring(0, 4000)
              : question,
        },
      ],
    });
  }
  return turns;
}

Map<String, dynamic> _parseModelResponse(String text) {
  var cleaned = text.trim();
  if (cleaned.startsWith('```')) {
    cleaned = cleaned.split('\n').skip(1).join('\n').split('```').first.trim();
  }
  final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
  for (final field in [
    'observations',
    'trainingSuggestions',
    'professionalReviewQuestions',
    'limitations',
    'evidenceUsed',
  ]) {
    if (parsed[field] is! List) parsed[field] = <String>[];
  }
  parsed['isDemo'] = false;
  parsed['basedOn'] ??= 'Gemini analysis of supplied movement telemetry';
  return parsed;
}

void _addCorsHeaders(HttpResponse response) {
  response.headers
    ..set('Access-Control-Allow-Origin', '*')
    ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    ..set('Access-Control-Allow-Headers', 'Content-Type');
}

Future<void> _writeJson(HttpResponse response, Object body) async {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}
