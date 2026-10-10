import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/athlete_os_components.dart';
import '../../data/models/athlete_profile.dart';
import '../../data/repositories/local_rehab_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/gemini_ai_coach_provider.dart';
import '../../data/services/ai_coach_service.dart';
import '../../domain/models/pose_models.dart';
import '../../domain/services/progress_service.dart';

class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.text,
    this.evidenceUsed = const [],
    this.basedOn = '',
    this.response,
    this.isAi = false,
  });

  final String sender;
  final String text;
  final List<String> evidenceUsed;
  final String basedOn;
  final AiCoachResponse? response;
  final bool isAi;
}

class AiCoachChatPage extends StatefulWidget {
  const AiCoachChatPage({super.key});

  @override
  State<AiCoachChatPage> createState() => _AiCoachChatPageState();
}

class _AiCoachChatPageState extends State<AiCoachChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _coachAgent = const OfflineMovementCoachAgent();
  final _geminiProvider = GeminiAiCoachProvider();
  late final ProviderBackedAiCoachService _modelCoach =
      ProviderBackedAiCoachService(_geminiProvider);
  final _tts = FlutterTts();

  AthleteProfile _profile = const AthleteProfile(name: 'Athlete');
  List<SessionRecord> _sessions = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isProviderReady = false;
  bool _isCheckingProvider = false;
  bool _voiceEnabled = true;
  bool _isSpeaking = false;
  String? _voiceError;
  CoachLanguage _language = CoachLanguage.english;
  AiCoachResponse? _latestResponse;
  String _providerStatusMessage = 'Checking Gemini backend…';

  static const _coachName = 'Mitra';

  final List<ChatMessage> _messages = [];
  late final Future<void> _providerInitialization;

  final List<String> _suggestedPrompts = [
    'Why was my movement consistency lower today?',
    'How should I approach my next rehabilitation session?',
    'What did my recent range-of-motion trend show?',
    'Are there any bilateral asymmetry observations?',
    'How do I fix that?',
  ];

  @override
  void initState() {
    super.initState();
    _configureVoice();
    _providerInitialization = _initializeProvider();
    _load();
  }

  Future<void> _initializeProvider() async {
    try {
      await _modelCoach.initialize().timeout(const Duration(seconds: 3));
    } on Object catch (error) {
      _providerStatusMessage =
          'Could not check Gemini backend: $error';
    }
    _isProviderReady = _modelCoach.isConfigured;
    if (_modelCoach.provider is GeminiAiCoachProvider) {
      _providerStatusMessage = _geminiProvider.statusMessage;
    }
  }

  Future<void> _retryProviderConnection() async {
    setState(() => _isCheckingProvider = true);
    await _initializeProvider();
    if (mounted) {
      setState(() => _isCheckingProvider = false);
    }
  }

  Future<void> _configureVoice() async {
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _tts.setQueueMode(0);
    }
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setCancelHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _voiceError = _language == CoachLanguage.tamil
              ? 'தமிழ் குரல் கிடைக்கவில்லை. சாதனத்தில் Tamil text-to-speech voice-ஐ நிறுவுங்கள்.'
              : 'Voice playback is unavailable on this device.';
        });
      }
    });
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await LocalRehabRepository(prefs).loadProfile();
    final sessions = verifiedMovementSessions(
      await LocalSessionRepository(prefs).readAll('athlete'),
    );
    await _providerInitialization;
    final loadedProfile = profile ?? _profile;
    final loadedContext = CoachContext(
      profile: loadedProfile,
      sessions: sessions,
      currentSession: sessions.isNotEmpty ? sessions.first : null,
      previousSession: sessions.length > 1 ? sessions[1] : null,
    );
    final initialResponse = _coachAgent.answer(
      'What should I focus on today?',
      loadedContext,
      language: _language,
    );

    if (mounted) {
      setState(() {
        _profile = loadedProfile;
        _sessions = sessions;
        _latestResponse = initialResponse;
        _isLoading = false;

        _messages.add(
          ChatMessage(
            sender: _isProviderReady ? _coachName : 'Mitra · LOCAL',
            text: _welcomeMessage(loadedProfile),
            isAi: true,
          ),
        );
      });
    }
  }

  String _welcomeMessage(AthleteProfile profile) {
    final name = profile.name.isEmpty ? 'Athlete' : profile.name;
    return _language == CoachLanguage.tamil
        ? 'வணக்கம் $name. நான் $_coachName. உங்கள் கேள்விகளுக்கு பதிலளிக்கவும், இயக்க அளவீடுகளை விளக்கவும், பயிற்சி முறையைப் பற்றி பேசவும் முடியும். மருத்துவ நோயறிதல் வழங்கமாட்டேன்.'
        : _isProviderReady
        ? 'Hi $name. I’m $_coachName. Ask me about movement, exercise technique, recovery, nutrition basics, or anything else you’re curious about. I can use your recorded measurements when relevant, but I can’t diagnose medical conditions.'
        : 'Hi $name. I’m $_coachName, your local movement coach. The Gemini service is not connected right now, but I can still explain recorded measurements and offer basic exercise guidance.';
  }

  Future<void> _sendMessage(String query) async {
    if (query.trim().isEmpty || _isSending) return;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(sender: 'You', text: query, isAi: false));
      _isSending = true;
    });

    final historyList = _messages.map((m) => {
      'role': m.isAi ? 'assistant' : 'user',
      'content': m.text,
    }).toList();

    final context = CoachContext(
      profile: _profile,
      sessions: _sessions,
      currentSession: _sessions.isNotEmpty ? _sessions.first : null,
      previousSession: _sessions.length > 1 ? _sessions[1] : null,
      conversationHistory: historyList,
      responseLanguage: _language == CoachLanguage.tamil ? 'Tamil' : 'English',
    );

    late AiCoachResponse response;
    var isLocalResponse = !_modelCoach.isConfigured;
    try {
      if (isLocalResponse) throw StateError('Gemini backend is unavailable.');
      response = await _modelCoach
          .structuredAnswer(query, context)
          .timeout(const Duration(seconds: 35));
    } catch (_) {
      isLocalResponse = true;
      _isProviderReady = false;
      _providerStatusMessage = _geminiProvider.statusMessage;
      response = _coachAgent.answer(query, context, language: _language);
    }

    final responseText = isLocalResponse
        ? response.toStructuredMarkdown(language: _language)
        : response.summary;

    if (!mounted) return;
    setState(() {
      _latestResponse = response;
      _isSending = false;
      _messages.add(
        ChatMessage(
          sender: isLocalResponse ? 'Mitra · LOCAL' : _coachName,
          text: responseText,
          evidenceUsed: response.evidenceUsed,
          basedOn: response.basedOn,
          response: response,
          isAi: true,
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    if (_voiceEnabled) await _speak(response);
  }

  Future<void> _speak(AiCoachResponse response) async {
    final details = [
      response.whatIObserved,
      response.whatItMeans,
      response.howToImprove,
      response.nextAttemptCue,
    ].where((part) => part.trim().isNotEmpty).join('. ');
    final text = details.isEmpty ? response.summary : details;
    if (text.isEmpty) return;
    await _stopSpeaking();
    final locale = _language == CoachLanguage.tamil ? 'ta-IN' : 'en-US';
    try {
      if (!kIsWeb) {
        final available = await _tts.isLanguageAvailable(locale);
        if (available == false) {
          throw StateError('The $locale voice is not available.');
        }
      }
      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(
        _language == CoachLanguage.tamil ? 0.58 : 0.54,
      );
      await _selectVoice(locale);
      if (!mounted) return;
      setState(() => _voiceError = null);
      setState(() => _isSpeaking = true);
      await _tts.speak(text, focus: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _voiceError = _language == CoachLanguage.tamil
              ? 'தமிழ் குரல் கிடைக்கவில்லை. Android/iOS-ல் Tamil TTS voice-ஐ நிறுவி மீண்டும் முயற்சிக்கவும்.'
              : 'English voice playback is unavailable on this device.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_voiceError!)),
        );
      }
    }
  }

  Future<void> _selectVoice(String locale) async {
    final voices = await _tts.getVoices;
    if (voices is! List) return;
    final matchingVoice = voices.whereType<Map>().firstWhere(
      (voice) {
        final voiceLocale = '${voice['locale'] ?? ''}'.toLowerCase();
        return voiceLocale == locale.toLowerCase() ||
            voiceLocale.startsWith(locale.substring(0, 2).toLowerCase());
      },
      orElse: () => <String, String>{},
    );
    if (matchingVoice.isNotEmpty && matchingVoice['name'] != null) {
      await _tts.setVoice({
        'name': '${matchingVoice['name']}',
        'locale': '${matchingVoice['locale'] ?? locale}',
      });
    }
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _changeLanguage(CoachLanguage language) async {
    await _stopSpeaking();
    if (!mounted) return;
    setState(() => _language = language);
  }

  @override
  void dispose() {
    unawaited(_tts.stop());
    unawaited(_modelCoach.dispose());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final response = _latestResponse;
    final insight = response?.whatIObserved.isNotEmpty == true
        ? response!.whatIObserved
        : (response?.observations.firstOrNull ?? 'Complete a movement session to generate a measured insight.');
    final focus = response?.howToImprove.isNotEmpty == true
        ? response!.howToImprove
        : (response?.trainingSuggestions.firstOrNull ?? 'Record five controlled repetitions for a reliable baseline.');
    final action = response?.nextAttemptCue.isNotEmpty == true
        ? response!.nextAttemptCue
        : (response?.summary ?? 'Ask about consistency, range of motion, symmetry, or recovery.');

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.electricCyan, size: 20),
            SizedBox(width: 10),
            Text(
              'MITRA COACH',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<CoachLanguage>(
            tooltip: 'Language',
            initialValue: _language,
            onSelected: _changeLanguage,
            itemBuilder: (_) => const [
              PopupMenuItem(value: CoachLanguage.english, child: Text('English')),
              PopupMenuItem(value: CoachLanguage.tamil, child: Text('தமிழ்')),
            ],
            icon: const Icon(Icons.translate),
          ),
          IconButton(
            tooltip: _voiceEnabled ? 'Mute Mitra' : 'Enable Mitra voice',
            onPressed: () async {
              if (_voiceEnabled) await _stopSpeaking();
              if (mounted) setState(() => _voiceEnabled = !_voiceEnabled);
            },
            icon: Icon(_voiceEnabled ? Icons.volume_up : Icons.volume_off),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: AppColors.panel,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _language == CoachLanguage.tamil
                              ? 'இணைக்கப்பட்ட AI உதவியாளர்; இயக்க அளவீடுகள் கிடைக்கும்போது மட்டும் பயன்படுத்தப்படும்.'
                              : _isProviderReady
                                  ? 'Gemini AI connected · recent conversation and available movement data are used for relevant answers.'
                                  : 'Gemini is offline. $_providerStatusMessage Replies use the local movement coach until connected.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (!_isProviderReady)
                        TextButton(
                          onPressed: _isCheckingProvider
                              ? null
                              : _retryProviderConnection,
                          child: _isCheckingProvider
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Retry'),
                        ),
                    ],
                  ),
                ),
                if (_voiceError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Text(
                      _voiceError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.energyOrange,
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      AiCoachInsightCard(
                        title: "TODAY'S INSIGHT",
                        content: insight,
                        icon: Icons.psychology,
                        accentColor: AppColors.electricCyan,
                      ),
                      const SizedBox(height: 12),

                      AiCoachInsightCard(
                        title: 'NEXT FOCUS',
                        content: focus,
                        icon: Icons.track_changes,
                        accentColor: AppColors.voltLime,
                      ),
                      const SizedBox(height: 12),

                      AiCoachInsightCard(
                        title: 'ACTION CUE',
                        content: action,
                        icon: Icons.bolt,
                        accentColor: AppColors.energyOrange,
                      ),
                      const SizedBox(height: 18),

                      // Screen 5: AI Neural Waveform Core
                      const AiWaveformVisualizer(),
                      const SizedBox(height: 18),

                      const Divider(color: AppColors.borderDivider),
                      const SizedBox(height: 10),

                      // Chat message stream
                      for (final msg in _messages)
                        _ChatBubble(
                          message: msg,
                          onSpeak: msg.response == null
                              ? null
                              : () => _speak(msg.response!),
                          isSpeaking: _isSpeaking,
                        ),
                      if (_isSending)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Mitra is thinking…',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Suggested Prompts Carousel
                Container(
                  height: 38,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestedPrompts.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final prompt = _suggestedPrompts[i];
                      return ActionChip(
                        label: Text(prompt, style: const TextStyle(fontSize: 11)),
                        backgroundColor: AppColors.panel,
                        side: const BorderSide(color: AppColors.line),
                          onPressed: _isSending ? null : () => _sendMessage(prompt),
                      );
                    },
                  ),
                ),

                // Input bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  color: AppColors.panel,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Ask your AI movement coach...',
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onSubmitted: _isSending ? null : _sendMessage,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: AppColors.cyan, foregroundColor: AppColors.ink),
                        onPressed: _isSending ? null : () => _sendMessage(_controller.text),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    this.onSpeak,
    this.isSpeaking = false,
  });
  final ChatMessage message;
  final VoidCallback? onSpeak;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    if (!message.isAi) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.panelLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cyan.withAlpha(80)),
          ),
          child: Text(message.text, style: const TextStyle(fontSize: 13.5, color: AppColors.text)),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14, right: 30),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: AppColors.cyan),
                const SizedBox(width: 6),
                Text(message.sender, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.cyan)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message.text,
              style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.text),
            ),
            if (onSpeak != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: isSpeaking ? 'Speaking' : 'Speak response',
                  onPressed: onSpeak,
                  icon: Icon(
                    isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
                    size: 18,
                    color: AppColors.cyan,
                  ),
                ),
              ),

            // Transparent Evidence Used (Requirement 47 & 48)
            if (message.evidenceUsed.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.panelLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('EVIDENCE USED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.green, letterSpacing: 0.6)),
                    const SizedBox(height: 6),
                    ...message.evidenceUsed.map((e) => Text('• $e', style: const TextStyle(fontSize: 11.5, color: AppColors.muted))),
                    if (message.basedOn.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Based on: ${message.basedOn}', style: const TextStyle(fontSize: 10, color: AppColors.cyan)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
