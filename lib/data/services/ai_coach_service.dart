import '../../data/models/athlete_profile.dart';
import '../../domain/models/pose_models.dart';
import '../../domain/models/personalized_plan.dart';

enum CoachLanguage { english, tamil }

class CoachContext {
  const CoachContext({
    required this.profile,
    required this.sessions,
    this.exerciseName,
    this.trends = const [],
    this.currentSession,
    this.previousSession,
    this.currentPlan,
    this.planProgress,
    this.limitations = const [],
    this.conversationHistory = const [],
    this.responseLanguage,
  });
  final AthleteProfile profile;
  final List<SessionRecord> sessions;
  final String? exerciseName;
  final List<String> trends;
  final SessionRecord? currentSession;
  final SessionRecord? previousSession;
  final PersonalizedPlan? currentPlan;
  final PlanProgress? planProgress;
  final List<String> limitations;
  final List<Map<String, String>> conversationHistory;
  final String? responseLanguage;

  Map<String, Object?> toJson() => {
    'profile': profile.toJson(),
    'exerciseName': exerciseName,
    'trends': trends,
    'sessions': sessions.map((session) => session.toJson()).toList(),
    'currentSession': currentSession?.toJson(),
    'previousSession': previousSession?.toJson(),
    'currentPlan': currentPlan?.toJson(),
    'planProgress': planProgress?.toJson(),
    'limitations': limitations,
    'conversationHistory': conversationHistory,
    'responseLanguage': responseLanguage,
  };
}

class AiCoachResponse {
  const AiCoachResponse({
    required this.summary,
    required this.observations,
    required this.trainingSuggestions,
    required this.professionalReviewQuestions,
    required this.limitations,
    this.isDemo = false,
    this.evidenceUsed = const [],
    this.basedOn = 'Session movement telemetry',
    this.whatIObserved = '',
    this.whatItMeans = '',
    this.howToImprove = '',
    this.nextAttemptCue = '',
  });
  final String summary;
  final List<String> observations;
  final List<String> trainingSuggestions;
  final List<String> professionalReviewQuestions;
  final List<String> limitations;
  final bool isDemo;
  final List<String> evidenceUsed;
  final String basedOn;
  final String whatIObserved;
  final String whatItMeans;
  final String howToImprove;
  final String nextAttemptCue;

  String toStructuredMarkdown({CoachLanguage language = CoachLanguage.english}) {
    final buffer = StringBuffer();
    final observed = whatIObserved.isNotEmpty ? whatIObserved : (observations.isNotEmpty ? observations.join(' ') : summary);
    final means = whatItMeans.isNotEmpty ? whatItMeans : (summary.isNotEmpty ? summary : 'Kinematic execution reflects active motor control.');
    final improve = howToImprove.isNotEmpty ? howToImprove : (trainingSuggestions.isNotEmpty ? trainingSuggestions.join(' ') : 'Maintain controlled movement tempo.');
    final cue = nextAttemptCue.isNotEmpty ? nextAttemptCue : (trainingSuggestions.isNotEmpty ? trainingSuggestions.first : 'Perform repetitions with identical cadence.');

    final headings = language == CoachLanguage.tamil
        ? const ['நான் கவனித்தது', 'இதன் பொருள்', 'மேம்படுத்துவது எப்படி', 'அடுத்த முயற்சி']
        : const ['What I Observed', 'What It Means', 'How to Improve', 'Next Attempt'];
    buffer.writeln('### ${headings[0]}\n$observed\n');
    buffer.writeln('### ${headings[1]}\n$means\n');
    buffer.writeln('### ${headings[2]}\n$improve\n');
    buffer.writeln('### ${headings[3]}\n$cue\n');

    if (limitations.isNotEmpty) {
      final heading = language == CoachLanguage.tamil ? 'தரவு வரம்புகள்' : 'Data Limitations';
      buffer.writeln('### $heading\n${limitations.map((l) => '• $l').join('\n')}');
    }
    return buffer.toString().trim();
  }

  Map<String, Object?> toJson() => {
    'summary': summary,
    'observations': observations,
    'trainingSuggestions': trainingSuggestions,
    'professionalReviewQuestions': professionalReviewQuestions,
    'limitations': limitations,
    'isDemo': isDemo,
    'evidenceUsed': evidenceUsed,
    'basedOn': basedOn,
    'whatIObserved': whatIObserved,
    'whatItMeans': whatItMeans,
    'howToImprove': howToImprove,
    'nextAttemptCue': nextAttemptCue,
  };
}

abstract interface class AiCoachService {
  bool get isConfigured;
  Future<AiCoachResponse> structuredAnswer(String question, CoachContext context);
  Future<String> answer(String question, CoachContext context);
}

class UnavailableAiCoachService implements AiCoachService {
  @override
  bool get isConfigured => false;
  @override
  Future<AiCoachResponse> structuredAnswer(String question, CoachContext context) async => const AiCoachResponse(
    summary: 'AI Coach is currently unavailable because no AI provider is configured.',
    observations: [],
    trainingSuggestions: [],
    professionalReviewQuestions: [],
    limitations: ['No AI provider is configured.'],
    evidenceUsed: [],
    basedOn: 'Not Enough Data — external provider not configured',
    whatIObserved: 'No active connection to AI reasoning service.',
    whatItMeans: 'Telemetry interpretation is limited to local rule verification.',
    howToImprove: 'Connect the local AI server backend to enable multi-turn Gemini reasoning.',
    nextAttemptCue: 'Record movement sessions to build a local kinematic history.',
  );
  @override
  Future<String> answer(String question, CoachContext context) async =>
      'AI Coach is currently unavailable because no AI provider is configured.';
}

enum AiProviderStatus { unavailable, ready, error }

abstract interface class AiCoachProvider {
  AiProviderStatus get status;
  Future<void> initialize();
  Future<AiCoachResponse> generateCoachResponse(String question, CoachContext context);
  Future<void> dispose();
}

class UnavailableAiCoachProvider implements AiCoachProvider {
  @override
  AiProviderStatus get status => AiProviderStatus.unavailable;
  @override
  Future<void> initialize() async {}
  @override
  Future<AiCoachResponse> generateCoachResponse(String question, CoachContext context) async => const AiCoachResponse(
    summary: 'AI Coach is currently unavailable because no AI provider is configured.',
    observations: [],
    trainingSuggestions: [],
    professionalReviewQuestions: [],
    limitations: ['No AI provider is configured.'],
    evidenceUsed: [],
    basedOn: 'Not Enough Data',
  );
  @override
  Future<void> dispose() async {}
}

class AiSafetyFilter {
  static const _unsafeTerms = [
    'diagnos',
    'injury confirmation',
    'medically cleared',
    'medical clearance',
    'guaranteed recovery',
    'guaranteed return',
    'disease',
    'cure',
    '100% safe',
    'doctor replacement',
    'safe to play',
    'you have an injury',
    'acl is damaged',
    'safe to return to sport',
    'ligament tear',
    'tendon rupture',
    'medical diagnosis',
  ];

  AiCoachResponse validate(AiCoachResponse response, [CoachContext? context]) {
    final allText = [
      response.summary,
      response.whatIObserved,
      response.whatItMeans,
      response.howToImprove,
      response.nextAttemptCue,
      ...response.observations,
      ...response.trainingSuggestions,
      ...response.professionalReviewQuestions,
    ].join(' ').toLowerCase();

    if (_unsafeTerms.any(allText.contains)) {
      return const AiCoachResponse(
        summary: 'Direct clinical diagnosis or clearance was withheld. The movement data shows an asymmetry or kinematic variation that should be reviewed by a licensed physical therapist or sports medicine physician.',
        observations: ['Physical movement observation noted.'],
        trainingSuggestions: ['Focus on controlled tempo and pain-free range of motion.'],
        professionalReviewQuestions: ['Discuss measured movement observations with a qualified physical therapist or sports physician.'],
        limitations: [
          'Movement-analysis support, not medical diagnosis.',
          'REHAB-X AI provides movement-analysis support, not clinical medical diagnosis.',
          'Always obtain clinical clearance from your healthcare provider before advancing load.',
        ],
        evidenceUsed: ['Response verified by safety filter'],
        basedOn: 'Safety compliance policy',
        whatIObserved: 'Kinematic tracking observed joint angle variations requiring professional clinical interpretation.',
        whatItMeans: 'Camera-based pose estimation cannot inspect internal soft tissue, ligament integrity, or structural pathologies.',
        howToImprove: 'Halt any painful movement pattern and consult your physical therapist or orthopedist.',
        nextAttemptCue: 'Resume only exercises approved by your physical therapy protocol.',
      );
    }
    return response;
  }
}

class ProviderBackedAiCoachService implements AiCoachService {
  ProviderBackedAiCoachService(this.provider, {AiSafetyFilter? safetyFilter})
      : _safetyFilter = safetyFilter ?? AiSafetyFilter();
  final AiCoachProvider provider;
  final AiSafetyFilter _safetyFilter;
  @override
  bool get isConfigured => provider.status == AiProviderStatus.ready;
  @override
  Future<AiCoachResponse> structuredAnswer(String question, CoachContext context) async =>
      _safetyFilter.validate(await provider.generateCoachResponse(question, context));
  @override
  Future<String> answer(String question, CoachContext context) async =>
      (await structuredAnswer(question, context)).toStructuredMarkdown();
  Future<void> initialize() => provider.initialize();
  Future<void> dispose() => provider.dispose();
}

class ExplainableMovementCoach {
  const ExplainableMovementCoach();

  AiCoachResponse evaluateContext(String question, CoachContext context) {
    final cur = context.currentSession ?? (context.sessions.isNotEmpty ? context.sessions.first : null);
    final prev = context.previousSession ?? (context.sessions.length > 1 ? context.sessions[1] : null);
    
    // Resolve context from conversational history (follow-ups)
    String effectiveTopic = question.toLowerCase();
    if (context.conversationHistory.isNotEmpty) {
      final lastUserMsg = context.conversationHistory.lastWhere(
        (m) => m['role'] == 'user',
        orElse: () => const {'role': 'user', 'content': ''},
      )['content']?.toLowerCase() ?? '';
      
      final isFollowUp = effectiveTopic.contains('it') ||
          effectiveTopic.contains('that') ||
          effectiveTopic.contains('fix') ||
          effectiveTopic.contains('why') ||
          effectiveTopic.contains('how do i') ||
          effectiveTopic.contains('what about') ||
          effectiveTopic.length < 15;

      if (isFollowUp && lastUserMsg.isNotEmpty) {
        effectiveTopic = '$lastUserMsg $effectiveTopic';
      }
    }

    final observations = <String>[];
    final suggestions = <String>[];
    final evidence = <String>[];
    String whatIObserved = '';
    String whatItMeans = '';
    String howToImprove = '';
    String nextAttemptCue = '';
    String summary = '';

    bool mentions(List<String> terms) => terms.any(effectiveTopic.contains);

    if (cur != null) {
      final curMetrics = cur.metrics;
      final prevMetrics = prev?.metrics;

      evidence.addAll([
        '${curMetrics.repetitions} repetitions recorded',
        'Consistency: ${curMetrics.consistency.toStringAsFixed(1)}%',
        'Active ROM: ${curMetrics.rangeOfMotion.toStringAsFixed(1)}°',
        if (curMetrics.symmetry != null) 'Bilateral Asymmetry: ${curMetrics.symmetry!.toStringAsFixed(1)}%',
        if (curMetrics.velocity != null) 'Peak Angular Velocity: ${curMetrics.velocity!.toStringAsFixed(1)} °/s',
        if (curMetrics.tempo != null) 'Tempo per rep: ${curMetrics.tempo!.toStringAsFixed(1)} s',
        if (prevMetrics != null) 'Previous Consistency: ${prevMetrics.consistency.toStringAsFixed(1)}%',
        if (prevMetrics != null) 'Previous Active ROM: ${prevMetrics.rangeOfMotion.toStringAsFixed(1)}°',
      ]);

      if (mentions(['consistency', 'repeatable', 'steady', 'lower', 'trend', 'variance'])) {
        if (prevMetrics != null) {
          final delta = curMetrics.consistency - prevMetrics.consistency;
          if (delta < 0) {
            whatIObserved = 'Your movement consistency dropped by ${delta.abs().toStringAsFixed(1)}% (from ${prevMetrics.consistency.toStringAsFixed(1)}% to ${curMetrics.consistency.toStringAsFixed(1)}%) across ${curMetrics.repetitions} repetitions.';
            whatItMeans = 'Inconsistent repetition timing or fluctuating descent depth indicates premature neuromuscular fatigue or rushing through the eccentric phase.';
            howToImprove = 'Implement a strict 3-second eccentric tempo. Focus on identical depth markers rather than maximizing speed.';
            nextAttemptCue = 'Count "1-2-3" slowly during lowering and pause for a half-second at the bottom on every rep.';
          } else {
            whatIObserved = 'Your movement consistency improved by ${delta.toStringAsFixed(1)}% (now at ${curMetrics.consistency.toStringAsFixed(1)}%) across ${curMetrics.repetitions} repetitions.';
            whatItMeans = 'Repetition trajectory and velocity inflection points were remarkably steady, reflecting strong motor unit synchronization.';
            howToImprove = 'Maintain this cadence baseline while progressively deepening your active range of motion by 3-5 degrees.';
            nextAttemptCue = 'Retain your current smooth rhythm while focusing on full depth.';
          }
        } else {
          whatIObserved = 'Baseline movement consistency measured at ${curMetrics.consistency.toStringAsFixed(1)}% across ${curMetrics.repetitions} repetitions with ${curMetrics.rangeOfMotion.toStringAsFixed(1)}° ROM.';
          whatItMeans = 'This establishes your initial kinematic benchmark. Higher consistency (>85%) minimizes joint shear stress.';
          howToImprove = 'Focus on an unhurried, rhythmic cadence to keep repetition durations within ±0.2 seconds of each other.';
          nextAttemptCue = 'Perform your next set with a metronome-like tempo across all repetitions.';
        }
      } else if (mentions(['asymmetry', 'balance', 'side', 'left', 'right', 'tilt', 'sway'])) {
        final symmetry = curMetrics.symmetry;
        if (symmetry == null) {
          whatIObserved = 'Bilateral symmetry was not measurable for this session because the camera was placed in a side/sagittal profile.';
          whatItMeans = 'Left-to-right differential loading requires a front-facing camera angle with bilateral joint visibility.';
          howToImprove = 'Place your camera directly facing you at chest height to capture bilateral hip, knee, and shoulder symmetry.';
          nextAttemptCue = 'Switch to a front-facing camera position for your next set.';
        } else {
          whatIObserved = 'Measured bilateral kinematic asymmetry is ${symmetry.toStringAsFixed(1)}% between left and right limb trajectories.';
          whatItMeans = symmetry > 12
              ? 'A >10% asymmetry indicates compensatory loading where the dominant limb absorbs greater ground reaction force.'
              : 'Symmetry is within optimal athletic threshold (under 12% asymmetry), showing balanced bilateral load distribution.';
          howToImprove = symmetry > 12
              ? 'Incorporate single-leg isometric holds and unilateral split squats to equalize stabilizer strength.'
              : 'Continue dual-limb compound movements while maintaining equal foot pressure.';
          nextAttemptCue = 'Focus on pressing through both heels simultaneously with identical force on the ascent.';
        }
      } else if (mentions(['rom', 'range of motion', 'range', 'depth', 'angle', 'degree', 'flexion', 'extension'])) {
        final rom = curMetrics.rangeOfMotion;
        whatIObserved = 'Active joint range of motion achieved ${rom.toStringAsFixed(1)}° at maximum inflection across ${curMetrics.repetitions} repetitions.';
        whatItMeans = rom < 70
            ? 'Depth was restricted or shallow, which limits the recruitment of key stabilizer muscles around the target joint.'
            : 'Target joint excursion demonstrated full functional range suitable for athletic rehabilitation.';
        howToImprove = 'Perform dynamic joint mobilizations (such as ankle dorsiflexion and hip openers) during your warmup.';
        nextAttemptCue = 'Aim for 5° deeper controlled inflection on your next set without compromising lumbar alignment.';
      } else if (mentions(['velocity', 'speed', 'fast', 'slow', 'tempo', 'cadence'])) {
        final velocity = curMetrics.velocity;
        final tempo = curMetrics.tempo;
        if (velocity == null && tempo == null) {
          whatIObserved = 'Joint angular velocity telemetry was not captured during this session.';
          whatItMeans = 'Velocity tracking requires high-frame-rate tracking with full limb visibility throughout the rep.';
          howToImprove = 'Ensure high-contrast lighting and unobstructed line of sight to capture velocity telemetry.';
          nextAttemptCue = 'Maintain a steady 2-second eccentric and 1-second concentric rhythm on your next set.';
        } else {
          final velStr = velocity != null ? '${velocity.toStringAsFixed(1)} °/s' : 'N/A';
          final tempoStr = tempo != null ? '${tempo.toStringAsFixed(1)}s' : 'N/A';
          whatIObserved = 'Measured peak joint velocity was $velStr with an average repetition tempo of $tempoStr.';
          whatItMeans = 'Smooth velocity deceleration at the inflection point protects connective tissue from abrupt shock loading.';
          howToImprove = 'Control the turnaround transition smoothly rather than bouncing out of the bottom position.';
          nextAttemptCue = 'Pause for 1 full second at the bottom of the movement before accelerating upward.';
        }
      } else if (mentions(['pain', 'hurt', 'ache', 'injury', 'swelling', 'tear', 'sore'])) {
        whatIObserved = 'You mentioned pain, discomfort, or potential injury during movement.';
        whatItMeans = 'Camera pose estimation tracks joint angles but cannot assess internal tissue pathology or pain etiology.';
        howToImprove = 'Stop any movement that induces sharp pain or discomfort. Do not push through joint pain.';
        nextAttemptCue = 'Consult your licensed physical therapist or medical doctor for a clinical evaluation before resuming.';
      } else {
        whatIObserved = 'Recent session recorded ${curMetrics.repetitions} repetitions with ${curMetrics.consistency.toStringAsFixed(1)}% consistency and ${curMetrics.rangeOfMotion.toStringAsFixed(1)}° active ROM.';
        whatItMeans = 'Kinematic stability and neuromuscular control are tracking positively along your rehabilitation trajectory.';
        howToImprove = 'Focus on maintaining controlled eccentric lowering tempo across all repetitions.';
        nextAttemptCue = 'Keep your core braced and complete 5 repetitions with strict form.';
      }

      observations.add(whatIObserved);
      suggestions.add(howToImprove);
      summary = '$whatIObserved $whatItMeans $howToImprove';

      return AiCoachResponse(
        summary: summary,
        observations: observations,
        trainingSuggestions: suggestions,
        professionalReviewQuestions: const [
          'Do you feel equal bilateral load distribution throughout the movement?',
          'Are you maintaining steady diaphragmatic breathing and core bracing?',
        ],
        limitations: const [
          'Analysis is derived from on-device 2D kinematic pose estimation.',
          'Not intended to replace clinical examination by a licensed healthcare professional.',
        ],
        evidenceUsed: evidence,
        basedOn: prev != null ? 'Measured multi-session telemetry' : 'Measured baseline telemetry',
        whatIObserved: whatIObserved,
        whatItMeans: whatItMeans,
        howToImprove: howToImprove,
        nextAttemptCue: nextAttemptCue,
      );
    }

    // Proactive coaching when no sessions are recorded yet
    final sport = context.profile.sport.isEmpty ? 'Athletic Training' : context.profile.sport;
    final stage = context.profile.recoveryStage;

    if (mentions(['squat', 'depth', 'knee', 'angle', 'degree', 'flexion'])) {
      whatIObserved = 'Biomechanically optimal squat form requires 85°-95° knee flexion with knees tracking over the second toe.';
      whatItMeans = 'Preventing medial knee valgus and excessive forward torso lean reduces patellofemoral shear stress.';
      howToImprove = 'Prime ankle dorsiflexion and engage hip abductors (gluteus medius) before loading.';
      nextAttemptCue = 'Anchor all three foot contact points (heel, big toe, little toe) and sit back into your hips.';
    } else if (mentions(['recovery', 'recover', 'fatigue', 'rest', 'energy', 'sleep'])) {
      whatIObserved = 'Your profile is currently categorized under the "$stage" recovery stage.';
      whatItMeans = 'Neuromuscular remodeling and tendon adaptation require 48-72 hours of progressive recovery windows.';
      howToImprove = 'Perform 10 minutes of low-intensity mobility, maintain hydration, and prioritize 8 hours of sleep.';
      nextAttemptCue = 'Complete light dynamic warm-up drills before your next tracked analysis.';
    } else if (mentions(['camera', 'record', 'session', 'analyze', 'setup'])) {
      whatIObserved = 'No camera session is currently recorded for analysis.';
      whatItMeans = 'Place your phone against a stable support 2.5 meters away at waist level.';
      howToImprove = 'Ensure your entire body from head to ankles is in frame before tapping Start Analysis.';
      nextAttemptCue = 'Step into the camera frame and align with the silhouette guide.';
    } else if (mentions(['rom', 'range of motion', 'range-of-motion', 'range', 'trend', 'flexion', 'degree'])) {
      whatIObserved = 'Your range-of-motion trend requires at least one recorded movement session.';
      whatItMeans = 'Once recorded, we track angular joint excursion across concentric and eccentric phases.';
      howToImprove = 'Record a baseline movement set to establish your personal range-of-motion benchmark.';
      nextAttemptCue = 'Complete 5 repetitions of your prescribed exercise with the camera active.';
    } else if (mentions(['help', 'what can you', 'what should i ask'])) {
      whatIObserved = 'I am your on-device AI movement and rehabilitation coach, ready to help.';
      whatItMeans = 'I can explain kinematic consistency, range of motion, bilateral asymmetry, repetition cadence, and technique fixes.';
      howToImprove = 'Ask me specific questions about your movement data or how to perform an exercise with proper form.';
      nextAttemptCue = 'Try asking: "How should I improve my squat depth?" or "What does my consistency mean?"';
    } else if (mentions(['asymmetry', 'balance', 'left', 'right', 'side'])) {
      whatIObserved = 'Bilateral limb symmetry is essential for injury prevention and balanced power transfer in $sport.';
      whatItMeans = 'Strength or mobility discrepancies between limbs alter ground reaction force distribution.';
      howToImprove = 'Perform single-leg balance holds and split squats to strengthen stabilizer muscles.';
      nextAttemptCue = 'Hold a 30-second single-leg stance on each side with eyes fixed on a level horizon.';
    } else if (mentions(['pain', 'hurt', 'ache', 'injury', 'swelling'])) {
      whatIObserved = 'Camera-based kinematics cannot diagnose the clinical cause of pain or discomfort.';
      whatItMeans = 'Pain is an important signal to protect healing tissue from excessive mechanical load.';
      howToImprove = 'Pause painful movements immediately and consult a qualified healthcare professional.';
      nextAttemptCue = 'Resume movement only after clinical clearance from your physical therapist.';
    } else {
      whatIObserved = 'No movement sessions have been recorded on this device yet.';
      whatItMeans = 'Kinematic telemetry (ROM, consistency, velocity, symmetry) will unlock after your first recorded set.';
      howToImprove = 'Open Live Analysis, stand 2.5 meters from the camera, and complete 5 controlled repetitions.';
      nextAttemptCue = 'Start your first live camera analysis session to establish your personal movement baseline.';
    }

    observations.add(whatIObserved);
    suggestions.add(howToImprove);
    summary = '$whatIObserved $whatItMeans $howToImprove';

    return AiCoachResponse(
      summary: summary,
      observations: observations,
      trainingSuggestions: suggestions,
      professionalReviewQuestions: const [
        'Have you completed your dynamic mobility warmup today?',
        'Are there specific joints requiring extra stabilization focus?',
      ],
      limitations: const [
        'Kinematic guidance based on sports biomechanics principles.',
        'Not a substitute for clinical diagnosis.',
      ],
      evidenceUsed: [
        'Profile: $sport ($stage stage)',
        'Kinematic Engine: On-Device Ready',
      ],
      basedOn: 'On-Device Sports Biomechanics Engine',
      whatIObserved: whatIObserved,
      whatItMeans: whatItMeans,
      howToImprove: howToImprove,
      nextAttemptCue: nextAttemptCue,
    );
  }
}

class OfflineMovementCoachAgent {
  const OfflineMovementCoachAgent();

  AiCoachResponse answer(
    String question,
    CoachContext context, {
    CoachLanguage language = CoachLanguage.english,
  }) {
    final previousQuestion = context.conversationHistory
        .where((message) => message['role'] == 'user')
        .map((message) => message['content'] ?? '')
        .where((message) => message.trim().isNotEmpty && message != question)
        .lastOrNull;
    final isFollowUp = _matches(question.toLowerCase(), const [
      'that', 'it', 'this', 'how do i fix', 'what about', 'அதை', 'இதைக்', 'அது',
    ]);
    final text = '${isFollowUp ? previousQuestion ?? '' : ''} ${question.toLowerCase()}';
    final profileName = context.profile.name.trim().isEmpty
        ? (language == CoachLanguage.tamil ? 'நண்பரே' : 'Athlete')
        : context.profile.name.trim();
    final session = context.currentSession ??
        (context.sessions.isNotEmpty ? context.sessions.first : null);
    final metrics = session?.metrics;
    final tamil = language == CoachLanguage.tamil;

    final asksPain = _matches(text, const [
      'pain', 'hurt', 'ache', 'injury', 'swelling', 'வலி', 'காயம்', 'வீக்கம்',
    ]);
    final asksFood = _matches(text, const [
      'food', 'eat', 'diet', 'nutrition', 'meal', 'சாப்பாடு', 'உணவு', 'ஊட்டச்சத்து', 'சாப்பிட',
    ]);
    final asksExercise = _matches(text, const [
      'exercise', 'form', 'technique', 'properly', 'how to do', 'எப்படி செய்வது', 'சரியாக செய்வது', 'பயிற்சி முறை',
    ]);
    final asksWorkout = _matches(text, const [
      'workout', 'training plan', 'routine', 'what should i do', 'பயிற்சி திட்டம்', 'உடற்பயிற்சி திட்டம்', 'என்ன செய்யலாம்',
    ]);
    final asksMeasurement = _matches(text, const [
      'measurement', 'calculate', 'calculation', 'rom', 'range of motion',
      'symmetry', 'asymmetry', 'consistency', 'confidence', 'measure',
      'அளவீடு', 'கணக்கீடு', 'இயக்க வரம்பு', 'சமநிலை', 'நம்பகத்தன்மை',
    ]);

    final evidence = <String>[];
    if (session != null && metrics != null) {
      evidence.addAll([
        '${session.exercise}: ${metrics.repetitions} repetitions',
        'ROM: ${metrics.rangeOfMotion.toStringAsFixed(1)}°',
        'Consistency score: ${metrics.consistency.toStringAsFixed(1)}%',
        if (metrics.symmetry != null)
          'Measured bilateral difference: ${metrics.symmetry!.toStringAsFixed(1)}%',
        if (metrics.dataConfidence > 0)
          'Pose confidence: ${(metrics.dataConfidence * 100).toStringAsFixed(0)}%',
      ]);
    }

    late final String observed;
    late final String meaning;
    late final String improve;
    late final String cue;

    if (asksPain) {
      observed = tamil
          ? 'வலி அல்லது அசௌகரியம் இருப்பதாகச் சொன்னீர்கள், $profileName.'
          : 'You mentioned pain or discomfort, $profileName.';
      meaning = tamil
          ? 'கேமரா அளவீடு வலிக்கான காரணத்தையோ உட்புறத் திசுக்களையோ கண்டறியாது.'
          : 'Camera measurements cannot identify the cause of pain or assess internal tissue.';
      improve = tamil
          ? 'வலியை உண்டாக்கும் இயக்கத்தை நிறுத்துங்கள். தொடரும் அல்லது கடுமையான வலிக்கு தகுதியான சுகாதார நிபுணரை அணுகுங்கள்.'
          : 'Stop the movement that causes pain. For persistent or severe pain, contact a qualified healthcare professional.';
      cue = tamil
          ? 'வலி இல்லாத, உங்கள் நிபுணர் அனுமதித்த இயக்கங்களையே தொடருங்கள்.'
          : 'Continue only pain-free movements approved by your clinician.';
    } else if (asksFood) {
      observed = tamil
          ? '$profileName, உணவு ஆலோசனை உங்கள் அளவீடுகளிலிருந்து மருத்துவ உணவுத் திட்டமாக கணிக்கப்படாது.'
          : '$profileName, movement measurements do not determine a medical diet.';
      meaning = tamil
          ? 'பொதுவான பயிற்சி ஆதரவுக்கு காய்கறி/பழம், அரிசி அல்லது முழுதானியம், பருப்பு/முட்டை/மீன் போன்ற புரதம், மற்றும் தண்ணீர் சேர்த்த சமநிலையான உணவைத் தேர்ந்தெடுக்கலாம்.'
          : 'For general training support, build meals around vegetables or fruit, rice or whole grains, protein such as lentils, eggs, or fish, and water.';
      improve = tamil
          ? 'பயிற்சிக்கு முன் எளிதில் செரிக்கும் உணவைத் தேர்வு செய்யுங்கள்; பயிற்சிக்குப் பிறகு வழக்கமான சமநிலை உணவும் தண்ணீரும் போதுமான தொடக்கம். உணவு ஒவ்வாமை அல்லது மருத்துவ கட்டுப்பாடு இருந்தால் நிபுணரிடம் கேளுங்கள்.'
          : 'Choose familiar, easy-to-digest food before exercise; afterward, a balanced meal and water are a practical start. Ask a dietitian about allergies or medical restrictions.';
      cue = tamil
          ? 'இன்று தண்ணீர் குடித்து, உங்களுக்கு ஏற்ற வழக்கமான சமநிலை உணவைத் தேர்ந்தெடுக்கவும்.'
          : 'Today, hydrate and choose a balanced meal that fits your usual needs.';
    } else if (asksExercise) {
      final exerciseName = session?.exercise ??
          (tamil ? 'தேர்ந்தெடுத்த பயிற்சி' : 'your selected exercise');
      observed = tamil
          ? '$profileName, இப்போது பதிவான பயிற்சி: $exerciseName.'
          : '$profileName, the latest recorded exercise is $exerciseName.';
      meaning = tamil
          ? 'சரியான முறை பயிற்சியைப் பொறுத்தது; உங்கள் பயிற்சியாளர் அல்லது உடற்பயிற்சி நிபுணர் கொடுத்த வழிமுறையே முதன்மை.'
          : 'Good technique depends on the exercise; instructions from your coach or physical therapist take priority.';
      improve = tamil
          ? 'தொடங்குவதற்கு முன் இடத்தைத் தெளிவாக்கி, வசதியான நிலையை அமைத்து, மெதுவாக அசையுங்கள். உடலை கட்டுப்பாட்டில் வைத்து, மூச்சை விடாமல் பிடிக்காதீர்கள்; வலி வந்தால் நிறுத்துங்கள்.'
          : 'Clear the area, find a comfortable starting position, and move slowly with control. Keep breathing and stop if pain occurs.';
      cue = tamil
          ? 'முதலில் மெதுவான 3 முதல் 5 முயற்சிகள் செய்து, நிலைத்தன்மை இருந்தால் மட்டுமே தொடருங்கள்.'
          : 'Start with 3 to 5 slow practice repetitions; continue only while the movement stays controlled and pain-free.';
    } else if (asksWorkout) {
      observed = tamil
          ? '$profileName, இன்றைய பயிற்சி உங்கள் அனுமதிக்கப்பட்ட நிலை மற்றும் சோர்வைப் பொறுத்திருக்க வேண்டும்.'
          : '$profileName, today’s workout should match your approved activity level and how you feel.';
      meaning = tamil
          ? 'இந்த செயலி மருத்துவர் அல்லது உடற்பயிற்சி நிபுணரின் திட்டத்தை மாற்றாது; கேமரா மதிப்பெண் தனியாக பயிற்சி சுமையை நிர்ணயிக்காது.'
          : 'This app does not replace a clinician’s plan; a camera score alone cannot set training load.';
      improve = tamil
          ? 'அனுமதி இருந்தால் எளிய சூடுபடுத்தலுடன் தொடங்கி, உங்கள் திட்டத்தில் உள்ள இயக்கங்களை மட்டும் கட்டுப்பாட்டுடன் செய்யுங்கள். இடையில் ஓய்வு மற்றும் தண்ணீர் எடுத்துக்கொள்ளுங்கள்.'
          : 'If cleared for activity, begin with an easy warm-up and follow only exercises in your existing plan. Rest between efforts and hydrate.';
      cue = tamil
          ? 'இன்று புதிய எடை அல்லது கடினத்தன்மையைச் சேர்க்காமல், உங்கள் அங்கீகரிக்கப்பட்ட திட்டத்தையே பின்பற்றுங்கள்.'
          : 'Today, follow your approved plan without adding new load or difficulty.';
    } else if (asksMeasurement) {
      final rom = metrics?.rangeOfMotion;
      final consistency = metrics?.consistency;
      observed = tamil
          ? (metrics == null
              ? '$profileName, இன்னும் அளவிடப்பட்ட அமர்வு இல்லை. முதலில் ஒரு இயக்க அமர்வை பதிவு செய்யுங்கள்.'
              : '$profileName, ${session!.exercise} அமர்வில் ${metrics.repetitions} முறை பதிவாகி, ROM ${rom!.toStringAsFixed(1)}°, நிலைத்தன்மை ${consistency!.toStringAsFixed(1)}% ஆக இருந்தது.')
          : (metrics == null
              ? '$profileName, there is no measured session yet. Record a movement session to see your values.'
              : '$profileName, ${session!.exercise} recorded ${metrics.repetitions} repetitions, ROM ${rom!.toStringAsFixed(1)}°, and a consistency score of ${consistency!.toStringAsFixed(1)}%.');
      meaning = tamil
          ? 'ROM = கண்காணிக்கப்பட்ட அதிகபட்ச கோணம் − குறைந்தபட்ச கோணம். நிலைத்தன்மை இயக்கத் தரவின் மாறுபாட்டிலிருந்து உருவாக்கப்படும் மதிப்பெண். Pose நம்பகத்தன்மை, பகுப்பாய்வு செய்யப்பட்ட frames-இல் கண்டறியப்பட்ட புள்ளிகளின் சராசரி நம்பிக்கையைப் பிரதிபலிக்கிறது. இவை நோயறிதல் அல்ல.'
          : 'ROM = maximum observed joint angle minus minimum observed joint angle. Consistency is an exercise-specific score derived from movement variation. Pose confidence averages landmark confidence across analyzed frames. These measurements are not a clinical conclusion.';
      improve = tamil
          ? 'அதே கேமரா கோணம், முழு உடல் தெளிவாகத் தெரிதல், நிலையான வெளிச்சம் ஆகியவற்றைப் பயன்படுத்தி மீண்டும் அளவிடுங்கள். இடது-வலது ஒப்பீட்டிற்கு இரு பக்கங்களும் தெளிவாகத் தெரிய வேண்டும்.'
          : 'For a useful comparison, repeat with the same camera angle, clear full-body visibility, and steady lighting. Both sides must be visible for left-right comparison.';
      cue = tamil
          ? 'மதிப்பெண்ணை மட்டும் பார்க்காமல், அளவீட்டு நம்பகத்தன்மை மற்றும் ஒரே நிலைமையில் எடுத்த அமர்வுகளையும் ஒப்பிடுங்கள்.'
          : 'Compare sessions only under similar conditions and review confidence alongside the score.';
    } else {
      observed = tamil
          ? '$profileName, நான் உங்கள் அளவிடப்பட்ட இயக்கத் தரவை விளக்கவும், பயிற்சி முறையைச் சொல்லவும், பொதுவான உணவு வழிகாட்டுதலை வழங்கவும் முடியும்.'
          : '$profileName, I can explain measured movement data, walk through exercise technique, and offer general food guidance.';
      meaning = tamil
          ? 'என்னிடம் உள்ளவை பதிவு செய்யப்பட்ட அளவீடுகள் மட்டுமே; அவை மருத்துவ முடிவோ முழுமையான உடல் மதிப்பீடோ அல்ல.'
          : 'I use recorded measurements only; they are not a medical conclusion or a complete physical assessment.';
      improve = tamil
          ? 'அளவீடுகள், பயிற்சி முறை, வாராந்திர திட்டம் அல்லது உணவு பற்றி கேளுங்கள்.'
          : 'Ask about your measurements, exercise technique, a general workout structure, or food.';
      cue = tamil
          ? 'உதாரணம்: “என் ROM எப்படி கணக்கிடப்படுகிறது?” அல்லது “பயிற்சிக்கு முன் என்ன சாப்பிடலாம்?”'
          : 'Try: “How is my ROM calculated?” or “What can I eat before exercise?”';
    }

    final greeting = tamil ? 'வணக்கம் $profileName.' : 'Hi $profileName.';
    final limitations = tamil
        ? const ['இது இயக்கக் கண்காணிப்பு ஆதரவு மட்டுமே; மருத்துவ நோயறிதல் அல்லது தனிப்பட்ட உணவுத் திட்டம் அல்ல.']
        : const ['Movement coaching only; not a medical diagnosis or an individualized nutrition prescription.'];
    final response = AiCoachResponse(
      summary: '$greeting $observed $meaning $improve',
      observations: [observed],
      trainingSuggestions: [improve],
      professionalReviewQuestions: const [],
      limitations: limitations,
      evidenceUsed: evidence,
      basedOn: session == null ? 'On-device coaching guidance' : 'On-device session measurements',
      whatIObserved: observed,
      whatItMeans: meaning,
      howToImprove: improve,
      nextAttemptCue: cue,
    );
    return AiSafetyFilter().validate(response, context);
  }

  bool _matches(String text, List<String> phrases) =>
      phrases.any(text.contains);
}
