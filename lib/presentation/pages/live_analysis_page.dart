import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/athlete_os_components.dart';
import '../../data/models/exercise.dart';
import '../../data/repositories/local_rehab_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/camera_service.dart';
import '../../data/services/pose_detection_provider.dart';
import '../../domain/models/pose_models.dart';
import '../../domain/services/analysis_session_controller.dart';
import '../../domain/services/exercise_analyzers.dart';
import '../../domain/services/live_voice_feedback_service.dart';
import '../../domain/services/movement_features.dart';
import '../../domain/services/joint_telemetry_service.dart';
import '../../domain/services/technique_feedback_service.dart';
import '../../main.dart' show SessionDetailPage;
import '../widgets/camera_diagnostics_sheet.dart';

class LiveAnalysisPage extends StatefulWidget {
  const LiveAnalysisPage({
    super.key,
    required this.exercise,
    this.planId,
    this.planExerciseId,
  });

  final Exercise exercise;
  final String? planId;
  final String? planExerciseId;

  @override
  State<LiveAnalysisPage> createState() => _LiveAnalysisPageState();
}

class _LiveAnalysisPageState extends State<LiveAnalysisPage>
    with WidgetsBindingObserver {
  AnalysisSessionController? _controller;
  bool _showSetupGuide = true;
  bool _isFrontCamera = false;
  bool _debugMode = false;
  bool _showDetailedTelemetry = true;
  bool _voiceEnabled = true;
  VoiceFeedbackLanguage _voiceLanguage = VoiceFeedbackLanguage.english;
  bool _voiceReady = false;
  bool _isPreparingVoice = false;
  bool _isLiveVoiceSpeaking = false;
  String? _voiceError;
  int _telemetryCategoryIndex = 0;
  final _voice = FlutterTts();
  late final Future<void> _voiceInitialization;
  DateTime? _lastVoiceAt;
  String? _lastSpokenReport;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voiceInitialization = _configureLiveVoice();
    _initialize();
  }

  Future<void> _configureLiveVoice() async {
    _voice.setCompletionHandler(() => _isLiveVoiceSpeaking = false);
    _voice.setCancelHandler(() => _isLiveVoiceSpeaking = false);
    _voice.setErrorHandler((_) {
      _isLiveVoiceSpeaking = false;
      _voiceError = 'Voice playback failed. Check that speech is available on this device.';
      if (mounted) setState(() {});
    });
    try {
      await _voice.setVolume(1.0);
      await _voice.setPitch(1.0);
      await _voice.setSpeechRate(0.56);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _voice.setQueueMode(0);
      }
      _voiceReady = true;
    } catch (_) {
      _voiceError = 'Voice playback is unavailable on this device.';
    }
    if (mounted && _voiceError != null) {
      setState(() {});
    }
  }

  Future<void> _setVoiceEnabled(bool enabled) async {
    if (!enabled) {
      try {
        await _voice.stop();
      } catch (_) {
        _voiceError = 'Unable to stop speech playback on this device.';
      }
      _isLiveVoiceSpeaking = false;
    }
    if (!mounted) return;
    setState(() {
      _voiceEnabled = enabled;
      if (enabled) {
        _lastVoiceAt = null;
        _lastSpokenReport = null;
      }
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('live_analysis_voice_enabled', enabled);
    } catch (_) {
      // Keep the current-session toggle working if preference storage is unavailable.
    }
  }

  Future<void> _setVoiceLanguage(VoiceFeedbackLanguage language) async {
    if (_isLiveVoiceSpeaking) {
      try {
        await _voice.stop();
      } catch (_) {
        // The new language will be used on the next report even if stop fails.
      }
      _isLiveVoiceSpeaking = false;
    }
    if (!mounted) return;
    setState(() {
      _voiceLanguage = language;
      _lastSpokenReport = null;
      _lastVoiceAt = null;
      _voiceError = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('live_analysis_voice_language', language.name);
    } catch (_) {
      // Keep the selected language for this session if persistence is unavailable.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.pause();
    } else if (state == AppLifecycleState.resumed &&
        controller.status == AnalysisSessionStatus.paused) {
      controller.resume();
    }
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final savedVoiceEnabled = preferences.getBool('live_analysis_voice_enabled');
    final savedVoiceLanguage = preferences.getString('live_analysis_voice_language');
    final localRepository = LocalRehabRepository(preferences);
    final settings = await localRepository.loadSettings();
    _isFrontCamera = settings.frontCamera;

    final controller = AnalysisSessionController(
      camera: PluginCameraService(),
      pose: createPoseDetectionService(),
      sessions: LocalSessionRepository(preferences),
      planRepository: localRepository,
      planId: widget.planId,
      planExerciseId: widget.planExerciseId,
      athleteId: 'athlete',
      exerciseId: widget.exercise.id,
      exerciseName: widget.exercise.name,
      analyzer:
          getExerciseAnalyzer(widget.exercise.id) ?? const SquatAnalyzer(),
    );

    controller.addListener(_refresh);
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      if (savedVoiceEnabled != null) _voiceEnabled = savedVoiceEnabled;
        _voiceLanguage = savedVoiceLanguage == VoiceFeedbackLanguage.tamil.name
          ? VoiceFeedbackLanguage.tamil
          : VoiceFeedbackLanguage.english;
    });
    await controller.initialize(frontCamera: _isFrontCamera);

  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    unawaited(_announceLiveMeasurement());
  }

  Future<void> _announceLiveMeasurement() async {
    if (!_voiceEnabled ||
        _isPreparingVoice ||
        _isLiveVoiceSpeaking ||
        _controller?.status != AnalysisSessionStatus.running) {
      return;
    }
    _isPreparingVoice = true;
    final speechLanguage = _voiceLanguage;
    try {
      await _voiceInitialization;
      if (!_voiceReady ||
          !_voiceEnabled ||
          speechLanguage != _voiceLanguage ||
          _controller?.status != AnalysisSessionStatus.running) {
        return;
      }
      final controller = _controller!;
      final config = controller.analyzer.config;
      final angle = const JointTelemetryService().primaryAngle(
        controller.latestPose,
        config,
      );
      final phase = switch (controller.currentPhase) {
        RepetitionPhase.ascending => 'ASCENDING',
        RepetitionPhase.descending => 'DESCENDING',
        RepetitionPhase.bottom => 'BOTTOM',
        RepetitionPhase.completed => 'COMPLETED',
        RepetitionPhase.ready => 'READY',
      };
      final report = const LiveVoiceFeedbackService().buildReport(
        config: config,
        metrics: controller.liveMetrics,
        primaryAngle: angle,
        movementPhase: phase,
        coachingCue: controller.liveCoachingCue,
        language: speechLanguage,
      );
      final now = DateTime.now();
      final enoughTime = _lastVoiceAt == null ||
          now.difference(_lastVoiceAt!).inMilliseconds >= 1000;
      if (!enoughTime || report == _lastSpokenReport) return;

      _lastVoiceAt = now;
      _lastSpokenReport = report;
      final locale = speechLanguage == VoiceFeedbackLanguage.tamil
          ? 'ta-IN'
          : 'en-US';
      if (!kIsWeb && await _voice.isLanguageAvailable(locale) == false) {
        throw StateError('The $locale speech voice is unavailable.');
      }
      if (!_voiceEnabled ||
          speechLanguage != _voiceLanguage ||
          controller.status != AnalysisSessionStatus.running) {
        return;
      }
      await _voice.setLanguage(locale);
      if (mounted && _voiceError != null) setState(() => _voiceError = null);
      _isLiveVoiceSpeaking = true;
      await _voice.speak(report, focus: true);
    } catch (_) {
      _isLiveVoiceSpeaking = false;
      _voiceError = speechLanguage == VoiceFeedbackLanguage.tamil
          ? 'Tamil speech is unavailable. Install the Tamil speech voice on this device.'
          : 'Voice playback failed. Check that speech is available on this device.';
      if (mounted) setState(() {});
    } finally {
      _isPreparingVoice = false;
    }
  }

  Future<void> _switchCamera() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _isFrontCamera = !_isFrontCamera);
    await controller.initialize(frontCamera: _isFrontCamera);

  }

  bool get _isActualFrontCamera {
    final cameraController = _controller?.camera.controller;
    if (cameraController != null && cameraController.value.isInitialized) {
      return cameraController.description.lensDirection ==
          CameraLensDirection.front;
    }
    return _isFrontCamera;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    unawaited(_voice.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final readiness = controller?.readinessEvaluation;
    final liveMetrics = controller?.liveMetrics;
    final latestPose = controller?.latestPose;

    final primaryJointName =
        controller?.analyzer.config.primaryJointName ?? 'JOINT';
    final primaryAngleDeg = controller == null
        ? null
        : const JointTelemetryService().primaryAngle(
            latestPose,
            controller.analyzer.config,
          );
    final int repCount = liveMetrics?.repetitions ?? 0;
    final int poseConfidencePct = liveMetrics != null
        ? (liveMetrics.dataConfidence * 100).toInt()
        : ((readiness?.confidence ?? 0.0) * 100).toInt();

    final velocityText = liveMetrics?.velocity?.toStringAsFixed(1) ?? 'N/A';
    final consistencyText = liveMetrics == null
      ? 'N/A'
      : '${liveMetrics.consistency.toStringAsFixed(1)}%';
    final symmetryText = liveMetrics?.symmetry == null
      ? 'N/A'
      : '${liveMetrics!.symmetry!.toStringAsFixed(1)}%';

    final String movementPhaseName = switch (controller?.currentPhase) {
      RepetitionPhase.ascending => 'ASCENDING',
      RepetitionPhase.descending => 'DESCENDING',
      RepetitionPhase.bottom => 'BOTTOM',
      RepetitionPhase.completed => 'COMPLETED',
      RepetitionPhase.ready => 'READY',
      _ => 'POSITIONING',
    };

    final isCameraReady =
        controller?.camera.controller != null &&
        controller!.camera.controller!.value.isInitialized;
    final cameraStatus = controller?.camera.status ?? CameraStatus.idle;

    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
          // -------------------------------------------------------------
          // LAYER 1: Full-Viewport Camera Preview & Skeleton Canvas
          // -------------------------------------------------------------
          Positioned.fill(
            child: _buildCameraViewport(
              controller,
              isCameraReady,
              cameraStatus,
            ),
          ),

          // -------------------------------------------------------------
          // LAYER 2: Body Silhouette Alignment Guide (Setup Phase)
          // -------------------------------------------------------------
          if (controller?.status != AnalysisSessionStatus.running &&
              _showSetupGuide)
            Positioned.fill(
              child: BodySilhouetteAlignmentGuide(
                isAligned: readiness?.isReady == true,
                alignmentProgress:
                    ((readiness?.checklist.visibleCount ?? 0) / 6.0).clamp(
                      0.0,
                      1.0,
                    ),
                cue: readiness?.statusMessage ?? 'ALIGN BODY TO SILHOUETTE',
              ),
            ),

          // -------------------------------------------------------------
          // LAYER 3: Top Floating Minimal Athletic Header
          // -------------------------------------------------------------
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    // Back Navigation Button
                    _GlassIconButton(
                      icon: Icons.arrow_back_ios_new,
                      size: 30,
                      iconSize: 14,
                      onPressed: () => Navigator.maybePop(context),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 4),

                    // Exercise Title & Live Status Chip
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.obsidian.withAlpha(210),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderDivider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color:
                                    controller?.status ==
                                        AnalysisSessionStatus.running
                                    ? AppColors.voltLime
                                    : (readiness?.isReady == true
                                           ? AppColors.electricCyan
                                           : AppColors.energyOrange),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                widget.exercise.name.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Elapsed Timer Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.obsidian.withAlpha(210),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderDivider),
                      ),
                      child: Text(
                        _formatElapsed(controller?.elapsed ?? Duration.zero),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          fontFeatures: [ui.FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),

                    // Technique Guide (How to Perform) Button
                    _GlassIconButton(
                      icon: Icons.menu_book_outlined,
                      iconColor: AppColors.voltLime,
                      size: 30,
                      iconSize: 14,
                      onPressed: () =>
                          _showTechniqueGuideModal(context, widget.exercise.id),
                      tooltip: 'How to Perform / Exercise Technique Guide',
                    ),
                    const SizedBox(width: 3),

                    // Setup Silhouette Toggle Button
                    _GlassIconButton(
                      icon: _showSetupGuide
                          ? Icons.accessibility_new
                          : Icons.accessibility_new_outlined,
                      iconColor: _showSetupGuide
                          ? AppColors.electricCyan
                          : AppColors.textSecondary,
                      size: 30,
                      iconSize: 14,
                      onPressed: () =>
                          setState(() => _showSetupGuide = !_showSetupGuide),
                      tooltip: 'Toggle Silhouette Guide',
                    ),
                    const SizedBox(width: 3),

                    // Camera Switch (Front/Back)
                    _GlassIconButton(
                      icon: Icons.flip_camera_ios_outlined,
                      iconColor: _isFrontCamera
                          ? AppColors.electricCyan
                          : AppColors.textPrimary,
                      size: 30,
                      iconSize: 14,
                      onPressed: controller == null ? null : _switchCamera,
                      tooltip: _isFrontCamera
                          ? 'Front Camera (Mirrored View)'
                          : 'Rear Camera',
                    ),
                    const SizedBox(width: 3),

                    // Developer Debug Mode Toggle
                    _GlassIconButton(
                      icon: _debugMode
                          ? Icons.bug_report
                          : Icons.analytics_outlined,
                      iconColor: _debugMode
                          ? AppColors.voltLime
                          : AppColors.electricCyan,
                      size: 30,
                      iconSize: 14,
                      onPressed: () {
                        setState(() => _debugMode = !_debugMode);
                        if (!_debugMode && controller != null) {
                          CameraDiagnosticsSheet.show(
                            context,
                            diagnostics: controller.diagnostics,
                            exerciseName: widget.exercise.name,
                            requiredLandmarks:
                                controller.analyzer.requiredLandmarks,
                          );
                        }
                      },
                      tooltip: 'Technical Diagnostics & Debug Mode',
                    ),
                    const SizedBox(width: 3),
                    _GlassIconButton(
                      icon: _voiceEnabled
                          ? Icons.volume_up_outlined
                          : Icons.volume_off_outlined,
                      iconColor: _voiceEnabled
                          ? AppColors.electricCyan
                          : AppColors.textSecondary,
                      size: 30,
                      iconSize: 14,
                      onPressed: () => _setVoiceEnabled(!_voiceEnabled),
                      tooltip: _voiceEnabled
                          ? 'Turn speech feedback off'
                          : 'Turn speech feedback on',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // -------------------------------------------------------------
          // LAYER 4: Multi-Person Safety Warning
          // -------------------------------------------------------------
          Positioned(
            top: 96,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (readiness?.isMultiPerson == true ||
                    controller?.status ==
                        AnalysisSessionStatus.multiPersonDetected)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusCritical.withAlpha(210),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.statusCritical),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Multiple people detected. Keep only one athlete in frame.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

              ],
            ),
          ),

          // -------------------------------------------------------------
          // LAYER 5: Developer Debug HUD Overlay (when enabled)
          // -------------------------------------------------------------
          if (_debugMode && controller != null)
            Positioned(
              top: 148,
              left: 16,
              child: _DeveloperDebugOverlay(
                controller: controller,
                isFrontCamera: _isActualFrontCamera,
                jointName: primaryJointName,
                jointAngle: primaryAngleDeg,
              ),
            ),
              ],
            ),
          ),

          // -------------------------------------------------------------
          // LAYER 6: Bottom Floating Minimal Athlete HUD & Telemetry
          // -------------------------------------------------------------
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.obsidian,
                border: Border(
                  top: BorderSide(color: AppColors.borderDivider),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_voiceError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.energyOrange.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.energyOrange.withAlpha(110),
                            ),
                          ),
                          child: Text(
                            _voiceError!,
                            style: const TextStyle(
                              color: AppColors.energyOrange,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.obsidian,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDivider),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _voiceEnabled
                                  ? Icons.volume_up_outlined
                                  : Icons.volume_off_outlined,
                              color: _voiceEnabled
                                  ? AppColors.electricCyan
                                  : AppColors.textSecondary,
                              size: 17,
                            ),
                            const SizedBox(width: 9),
                            const Expanded(
                              child: Text(
                                'VOICE FEEDBACK',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            PopupMenuButton<VoiceFeedbackLanguage>(
                              tooltip: 'Speech language',
                              initialValue: _voiceLanguage,
                              onSelected: (language) =>
                                  unawaited(_setVoiceLanguage(language)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.translate,
                                    color: AppColors.textSecondary,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _voiceLanguage == VoiceFeedbackLanguage.tamil
                                        ? 'தமிழ்'
                                        : 'EN',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: VoiceFeedbackLanguage.english,
                                  child: Text('English'),
                                ),
                                PopupMenuItem(
                                  value: VoiceFeedbackLanguage.tamil,
                                  child: Text('தமிழ்'),
                                ),
                              ],
                            ),
                            Text(
                              _voiceEnabled ? 'ON' : 'OFF',
                              style: TextStyle(
                                color: _voiceEnabled
                                    ? AppColors.electricCyan
                                    : AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Switch.adaptive(
                              value: _voiceEnabled,
                              onChanged: _setVoiceEnabled,
                              activeTrackColor: AppColors.electricCyan,
                            ),
                          ],
                        ),
                      ),
                      if (controller?.liveCoachingCue.isNotEmpty == true)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.obsidian,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.electricCyan.withAlpha(120),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.record_voice_over_outlined,
                                size: 16,
                                color: AppColors.electricCyan,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  controller!.liveCoachingCue,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (controller != null &&
                          (controller.status == AnalysisSessionStatus.running ||
                              controller.status ==
                                  AnalysisSessionStatus.lowConfidence ||
                              controller.status ==
                                  AnalysisSessionStatus.insufficientVisibility))
                        _MovementFeedbackCard(
                          issue: controller.movementIssue,
                          correction: controller.correctiveMethod,
                          nextAttemptCue: controller.nextAttemptCue,
                        ),
                      if (controller != null &&
                          (controller.status == AnalysisSessionStatus.running ||
                              controller.status ==
                                  AnalysisSessionStatus.lowConfidence ||
                              controller.status ==
                                  AnalysisSessionStatus.insufficientVisibility))
                        const SizedBox(height: 8),
                      // Collapsible & Expandable Detailed Kinematics Telemetry Scroll Ribbon
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.obsidian.withAlpha(235),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                controller?.status ==
                                    AnalysisSessionStatus.running
                                ? AppColors.electricCyan.withAlpha(120)
                                : AppColors.borderDivider,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(140),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header Toggle Row (Overflow-Proof)
                            InkWell(
                              onTap: () => setState(
                                () => _showDetailedTelemetry =
                                    !_showDetailedTelemetry,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.speed,
                                      color: AppColors.electricCyan,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'ANALYSIS DATA & KINEMATICS',
                                        style: TextStyle(
                                          color: AppColors.electricCyan,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (controller?.status ==
                                                        AnalysisSessionStatus
                                                            .running
                                                    ? AppColors.voltLime
                                                    : AppColors.electricCyan)
                                                .withAlpha(25),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color:
                                              (controller?.status ==
                                                          AnalysisSessionStatus
                                                              .running
                                                      ? AppColors.voltLime
                                                      : AppColors.electricCyan)
                                                  .withAlpha(120),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _showDetailedTelemetry
                                                ? 'HIDE OPTIONS'
                                                : 'SHOW ALL OPTIONS',
                                            style: TextStyle(
                                              color:
                                                  controller?.status ==
                                                      AnalysisSessionStatus
                                                          .running
                                                  ? AppColors.voltLime
                                                  : AppColors.electricCyan,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 9,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Icon(
                                            _showDetailedTelemetry
                                                ? Icons.keyboard_arrow_down
                                                : Icons.keyboard_arrow_up,
                                            size: 13,
                                            color:
                                                controller?.status ==
                                                    AnalysisSessionStatus
                                                        .running
                                                ? AppColors.voltLime
                                                : AppColors.electricCyan,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (_showDetailedTelemetry) ...[
                              const SizedBox(height: 8),
                              // Category Filter Chips
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    _TelemetryCategoryChip(
                                      label: 'ALL DATA',
                                      isSelected: _telemetryCategoryIndex == 0,
                                      onTap: () => setState(
                                        () => _telemetryCategoryIndex = 0,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    _TelemetryCategoryChip(
                                      label: 'KINEMATICS',
                                      isSelected: _telemetryCategoryIndex == 1,
                                      onTap: () => setState(
                                        () => _telemetryCategoryIndex = 1,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    _TelemetryCategoryChip(
                                      label: 'ENERGY & HEAT',
                                      isSelected: _telemetryCategoryIndex == 2,
                                      onTap: () => setState(
                                        () => _telemetryCategoryIndex = 2,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    _TelemetryCategoryChip(
                                      label: 'SYMMETRY',
                                      isSelected: _telemetryCategoryIndex == 3,
                                      onTap: () => setState(
                                        () => _telemetryCategoryIndex = 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Horizontal Scrollable Ribbon of Telemetry Cards (Scroll Model)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: [
                                    if (_telemetryCategoryIndex == 0 ||
                                        _telemetryCategoryIndex == 1) ...[
                                      _DetailedTelemetryScrollCard(
                                        label: primaryAngleDeg == null
                                          ? 'JOINT ANGLE'
                                          : '$primaryJointName ANGLE',
                                        value: primaryAngleDeg == null
                                          ? 'N/A'
                                          : '${primaryAngleDeg.toStringAsFixed(1)}°',
                                        unit: 'DEGREE',
                                        color: AppColors.electricCyan,
                                      ),
                                      const SizedBox(width: 6),
                                      _DetailedTelemetryScrollCard(
                                        label: 'VELOCITY',
                                        value: velocityText,
                                        unit: '°/s',
                                        color: AppColors.voltLime,
                                      ),
                                      const SizedBox(width: 6),
                                      _DetailedTelemetryScrollCard(
                                        label: 'CONSISTENCY',
                                        value: consistencyText,
                                        unit: 'PRECISION',
                                        color: AppColors.textPrimary,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    if (_telemetryCategoryIndex == 0 ||
                                        _telemetryCategoryIndex == 2) ...[
                                      _DetailedTelemetryScrollCard(
                                        label: 'ENERGY OUTPUT',
                                        value: 'N/A',
                                        unit: 'NOT MEASURED',
                                        color: AppColors.energyOrange,
                                      ),
                                      const SizedBox(width: 6),
                                      _DetailedTelemetryScrollCard(
                                        label: 'HEAT INDEX',
                                        value: 'N/A',
                                        unit: 'NOT MEASURED',
                                        color: AppColors.statusAttention,
                                      ),
                                      const SizedBox(width: 6),
                                      _DetailedTelemetryScrollCard(
                                        label: 'MOVEMENT PHASE',
                                        value: movementPhaseName,
                                        unit: 'KINETIC',
                                        color: AppColors.electricCyan,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    if (_telemetryCategoryIndex == 0 ||
                                        _telemetryCategoryIndex == 3) ...[
                                      _DetailedTelemetryScrollCard(
                                        label: 'BILATERAL SYMMETRY',
                                        value: symmetryText,
                                        unit: 'LEFT/RIGHT DIFFERENCE',
                                        color: AppColors.textPrimary,
                                      ),
                                      const SizedBox(width: 6),
                                      _DetailedTelemetryScrollCard(
                                        label: 'CADENCE',
                                        value: liveMetrics?.tempo != null
                                            ? '${liveMetrics!.tempo!.toStringAsFixed(1)}s'
                                          : 'N/A',
                                        unit: 'TEMPO / REP',
                                        color: AppColors.voltLime,
                                      ),
                                      const SizedBox(width: 6),
                                      _DetailedTelemetryScrollCard(
                                        label: 'CONFIDENCE',
                                        value: '$poseConfidencePct%',
                                        unit: 'ACCURACY',
                                        color: poseConfidencePct >= 75
                                            ? AppColors.voltLime
                                            : AppColors.energyOrange,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Minimal Glass Telemetry Bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.obsidian.withAlpha(230),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color:
                                controller?.status ==
                                    AnalysisSessionStatus.running
                                ? AppColors.electricCyan.withAlpha(120)
                                : AppColors.borderDivider,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(120),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // REPS
                            Expanded(
                              child: _MinimalHUDStat(
                                label: 'REPS',
                                value: repCount.toString().padLeft(2, '0'),
                                valueColor: AppColors.voltLime,
                                isLarge: true,
                              ),
                            ),
                            _HUDDivider(),
                            // PHASE
                            Expanded(
                              child: _MinimalHUDStat(
                                label: 'PHASE',
                                value: movementPhaseName,
                                valueColor: AppColors.electricCyan,
                              ),
                            ),
                            _HUDDivider(),
                            // POSE CONFIDENCE
                            Expanded(
                              child: _MinimalHUDStat(
                                label: 'POSE',
                                value: '$poseConfidencePct%',
                                valueColor: poseConfidencePct >= 75
                                    ? AppColors.voltLime
                                    : AppColors.energyOrange,
                              ),
                            ),
                            if (primaryAngleDeg != null) ...[
                              _HUDDivider(),
                              // JOINT ANGLE
                              Expanded(
                                child: _MinimalHUDStat(
                                  label: 'ANGLE',
                                  value:
                                      '${primaryAngleDeg.toStringAsFixed(0)}°',
                                  valueColor: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Primary Floating Action Buttons
                      Row(
                        children: [
                          // Reset / Recalibrate
                          _GlassSquareButton(
                            icon: Icons.refresh,
                            size: 44,
                            iconSize: 20,
                            tooltip: 'Reset Camera & Alignment',
                            onPressed: controller == null
                                ? null
                                : () => controller.initialize(
                                    frontCamera: _isFrontCamera,
                                  ),
                          ),
                          const SizedBox(width: 8),

                          // Primary Action Button (Start / Pause / Resume)
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      controller?.status ==
                                          AnalysisSessionStatus.running
                                      ? AppColors.energyOrange
                                      : AppColors.electricCyan,
                                  foregroundColor: AppColors.obsidian,
                                  elevation: 4,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed:
                                    controller?.status ==
                                        AnalysisSessionStatus.ready
                                    ? (controller?.canStartAnalysis == true
                                      ? () => controller!.start()
                                      : null)
                                    : controller?.status ==
                                          AnalysisSessionStatus.running
                                    ? () => controller!.pause()
                                    : controller?.status ==
                                          AnalysisSessionStatus.paused
                                    ? () => controller!.resume()
                                    : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      controller?.status ==
                                              AnalysisSessionStatus.running
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          controller?.status ==
                                                  AnalysisSessionStatus.running
                                              ? 'PAUSE'
                                              : controller?.status ==
                                                    AnalysisSessionStatus.paused
                                              ? 'RESUME'
                                              : 'START ANALYSIS',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            letterSpacing: 0.8,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Finish Button
                          _GlassSquareButton(
                            icon: Icons.stop_rounded,
                            iconColor: AppColors.statusCritical,
                            size: 44,
                            iconSize: 22,
                            tooltip: 'Finish Session & View Report',
                            onPressed: controller?.hasPoseData == true
                                ? () => _finishSession(context, controller!)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraViewport(
    AnalysisSessionController? controller,
    bool isCameraReady,
    CameraStatus cameraStatus,
  ) {
    if (cameraStatus == CameraStatus.denied ||
        cameraStatus == CameraStatus.permanentlyDenied) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.statusAttention),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: AppColors.statusAttention,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'CAMERA PERMISSION REQUIRED',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'REHAB-X AI requires camera access to track your body joints and analyze movement precision in real time.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electricCyan,
                  foregroundColor: AppColors.obsidian,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    _controller?.initialize(frontCamera: _isFrontCamera),
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'GRANT ACCESS & RETRY',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (cameraStatus == CameraStatus.unavailable ||
        cameraStatus == CameraStatus.error ||
        controller?.status == AnalysisSessionStatus.error) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderDivider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.statusCritical,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                cameraStatus == CameraStatus.unavailable ||
                        cameraStatus == CameraStatus.error
                    ? 'CAMERA UNAVAILABLE'
                    : 'ANALYSIS ENGINE UNAVAILABLE',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                controller?.errorMessage ??
                    'Unable to connect to the camera sensor or pose model. Check browser permissions and network access, then retry.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.electricCyan,
                  foregroundColor: AppColors.obsidian,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    _controller?.initialize(frontCamera: _isFrontCamera),
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'RETRY INITIALIZATION',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!isCameraReady) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const _SportsViewfinderBackground(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(AppColors.electricCyan),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'INITIALIZING COMPUTER VISION ENGINE...',
                  style: TextStyle(
                    color: AppColors.electricCyan.withAlpha(200),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final cameraValue = controller!.camera.controller!.value;
    final double aspectRatio =
        (controller.latestPose?.imageWidth != null &&
            controller.latestPose?.imageHeight != null &&
            controller.latestPose!.imageHeight! > 0)
        ? (controller.latestPose!.imageWidth!.toDouble() /
              controller.latestPose!.imageHeight!.toDouble())
        : (cameraValue.aspectRatio > 0
              ? (1.0 / cameraValue.aspectRatio)
              : (9 / 16));

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Live Camera Stream
                CameraPreview(controller.camera.controller!),

                // Real-time Anatomical Skeletal Overlay
                if (controller.latestPose != null)
                  CustomPaint(
                    painter: LivePoseSkeletonPainter(
                      frame: controller.latestPose!,
                      exerciseId: controller.analyzer.config.exerciseId,
                      isFrontCamera: _isActualFrontCamera,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatElapsed(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _finishSession(
    BuildContext context,
    AnalysisSessionController controller,
  ) async {
    try {
      final session = await controller.finish();
      if (!context.mounted || session == null) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SessionDetailPage(session: session)),
      );
    } on InsufficientMovementDataException catch (e) {
      if (context.mounted) {
        _showAnalysisIncompleteModal(context, e.message);
      }
    }
  }

  void _showAnalysisIncompleteModal(BuildContext context, String reason) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.graphite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.statusCritical,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'ANALYSIS INCOMPLETE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.statusCritical,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Reason:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reason,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderDivider),
                      minimumSize: const Size(0, 46),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() => _showSetupGuide = true);
                    },
                    child: const Text('Camera Setup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.electricCyan,
                      foregroundColor: AppColors.obsidian,
                      minimumSize: const Size(0, 46),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _controller?.initialize(frontCamera: _isFrontCamera);
                    },
                    child: const Text(
                      'Retry Analysis',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTechniqueGuideModal(BuildContext context, String exerciseId) {
    final guide = CorrectTechniqueGuide.getGuideForExercise(exerciseId);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.graphite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  const Icon(Icons.school, color: AppColors.voltLime, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'HOW TO PERFORM: ${guide.title.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.6,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: AppColors.borderDivider),
              const SizedBox(height: 8),

              _GuideSectionHeader(title: 'CAMERA PLACEMENT', icon: Icons.videocam_outlined),
              Text(guide.cameraPlacement, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4)),
              const SizedBox(height: 12),

              _GuideSectionHeader(title: 'STARTING POSTURE', icon: Icons.accessibility_new),
              Text(guide.startingPosture, style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4)),
              const SizedBox(height: 12),

              _GuideSectionHeader(title: 'EXECUTION PHASES', icon: Icons.format_list_numbered),
              ...guide.executionSteps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(step, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35)),
              )),
              const SizedBox(height: 12),

              _GuideSectionHeader(title: 'COMMON MISTAKES & HOW TO FIX', icon: Icons.warning_amber_rounded, color: AppColors.energyOrange),
              ...guide.commonMistakes.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.obsidian,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('⚠️ Mistake: ${m.mistake}', style: const TextStyle(color: AppColors.energyOrange, fontWeight: FontWeight.w800, fontSize: 11.5)),
                    const SizedBox(height: 4),
                    Text('✅ Fix: ${m.correction}', style: const TextStyle(color: AppColors.voltLime, fontWeight: FontWeight.w700, fontSize: 11.5)),
                  ],
                ),
              )),
              const SizedBox(height: 12),

              _GuideSectionHeader(title: 'BREATHING PATTERN', icon: Icons.air),
              Text(guide.breathingPattern, style: const TextStyle(fontSize: 12, color: AppColors.electricCyan, height: 1.35)),
              const SizedBox(height: 12),

              _GuideSectionHeader(title: 'TARGET JOINT ACTION', icon: Icons.straighten),
              Text(guide.targetJointAction, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// MINIMAL HUD COMPONENTS
// =========================================================================

class _MinimalHUDStat extends StatelessWidget {
  const _MinimalHUDStat({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isLarge = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: isLarge ? 20 : 13.5,
              fontWeight: FontWeight.w900,
              color: valueColor,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _HUDDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: AppColors.borderDivider);
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.iconColor = AppColors.textPrimary,
    this.size = 34,
    this.iconSize = 16,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color iconColor;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.obsidian.withAlpha(200),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDivider),
          ),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class _GlassSquareButton extends StatelessWidget {
  const _GlassSquareButton({
    required this.icon,
    required this.onPressed,
    this.iconColor = AppColors.textPrimary,
    this.size = 46,
    this.iconSize = 20,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color iconColor;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.graphite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderDivider),
          ),
          child: Icon(icon, color: iconColor, size: iconSize),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

class _MovementFeedbackCard extends StatelessWidget {
  const _MovementFeedbackCard({
    required this.issue,
    required this.correction,
    this.nextAttemptCue = '',
  });

  final String issue;
  final String correction;
  final String nextAttemptCue;

  @override
  Widget build(BuildContext context) {
    final isIssue = issue != 'No major technique issue detected';
    final accent = isIssue ? AppColors.energyOrange : AppColors.voltLime;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.obsidian.withAlpha(242),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(150)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIssue
                    ? Icons.build_circle_outlined
                    : Icons.check_circle_outline,
                color: accent,
                size: 17,
              ),
              const SizedBox(width: 7),
              Text(
                isIssue ? 'TECHNIQUE CORRECTION' : 'MOVEMENT TECHNIQUE',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'WHAT TO FIX',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            issue,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'CORRECT METHOD',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            correction,
            style: const TextStyle(
              color: AppColors.electricCyan,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (nextAttemptCue.isNotEmpty &&
              nextAttemptCue != 'Maintain controlled tempo throughout.') ...[
            const SizedBox(height: 7),
            const Text(
              'NEXT ATTEMPT CUE',
              style: TextStyle(
                color: AppColors.voltLime,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              nextAttemptCue,
              style: const TextStyle(
                color: AppColors.voltLime,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuideSectionHeader extends StatelessWidget {
  const _GuideSectionHeader({
    required this.title,
    required this.icon,
    this.color = AppColors.electricCyan,
  });

  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperDebugOverlay extends StatelessWidget {
  const _DeveloperDebugOverlay({
    required this.controller,
    required this.isFrontCamera,
    required this.jointName,
    required this.jointAngle,
  });

  final AnalysisSessionController controller;
  final bool isFrontCamera;
  final String jointName;
  final double? jointAngle;

  @override
  Widget build(BuildContext context) {
    final diag = controller.diagnostics;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.obsidian.withAlpha(220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.electricCyan.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, size: 12, color: AppColors.voltLime),
              SizedBox(width: 6),
              Text(
                'DEV TELEMETRY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.voltLime,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DebugRow(label: 'Camera FPS', value: diag.fps.toStringAsFixed(1)),
          _DebugRow(label: 'Pose FPS', value: diag.poseFps.toStringAsFixed(1)),
          _DebugRow(label: 'Latency', value: '${diag.latencyMs} ms'),
          _DebugRow(label: 'Resolution', value: diag.imageResolution),
          _DebugRow(
            label: 'Camera Lens',
            value: isFrontCamera ? 'Front (Mirrored)' : 'Rear',
          ),
          _DebugRow(label: 'Landmark Pipeline', value: 'Raw / Unmirrored'),
          _DebugRow(label: 'Total Frames', value: '${diag.totalFrames}'),
          _DebugRow(label: 'Valid Frames', value: '${diag.validFrames}'),
          _DebugRow(label: 'Dropped Frames', value: '${diag.droppedFrames}'),
          _DebugRow(
            label: '$jointName Angle',
            value: jointAngle == null
                ? 'N/A'
                : '${jointAngle!.toStringAsFixed(1)}°',
          ),
        ],
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFeatures: [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class LivePoseSkeletonPainter extends CustomPainter {
  LivePoseSkeletonPainter({
    required this.frame,
    required this.exerciseId,
    this.isFrontCamera = false,
  });

  final PoseFrame frame;
  final String exerciseId;
  final bool isFrontCamera;

  static const _connections = [
    // Head / Facial structure
    ('nose', 'leftEye'),
    ('leftEye', 'leftEar'),
    ('nose', 'rightEye'),
    ('rightEye', 'rightEar'),
    // Shoulder girdle
    ('leftShoulder', 'rightShoulder'),
    // Upper extremities (Arms & Hands)
    ('leftShoulder', 'leftElbow'),
    ('leftElbow', 'leftWrist'),
    ('leftWrist', 'leftThumb'),
    ('leftWrist', 'leftPinky'),
    ('leftWrist', 'leftIndex'),
    ('rightShoulder', 'rightElbow'),
    ('rightElbow', 'rightWrist'),
    ('rightWrist', 'rightThumb'),
    ('rightWrist', 'rightPinky'),
    ('rightWrist', 'rightIndex'),
    // Torso / Core
    ('leftShoulder', 'leftHip'),
    ('rightShoulder', 'rightHip'),
    ('leftHip', 'rightHip'),
    // Lower extremities (Legs & Feet)
    ('leftHip', 'leftKnee'),
    ('leftKnee', 'leftAnkle'),
    ('leftAnkle', 'leftHeel'),
    ('leftAnkle', 'leftFootIndex'),
    ('leftHeel', 'leftFootIndex'),
    ('rightHip', 'rightKnee'),
    ('rightKnee', 'rightAnkle'),
    ('rightAnkle', 'rightHeel'),
    ('rightAnkle', 'rightFootIndex'),
    ('rightHeel', 'rightFootIndex'),
  ];

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final sourceWidth = (frame.imageWidth ?? 1).toDouble();
    final sourceHeight = (frame.imageHeight ?? 1).toDouble();

    if (sourceWidth <= 0 || sourceHeight <= 0) return;

    ui.Offset point(PoseLandmark landmark) {
      final displayLandmark = PoseCoordinateTransformer.displayPose(
        landmark,
        imageWidth: sourceWidth,
        isFrontCamera: isFrontCamera,
      );
      final normX = displayLandmark.x / sourceWidth;
      final mappedY = displayLandmark.y / sourceHeight;
      return ui.Offset(normX * size.width, mappedY * size.height);
    }

    final glowPaint = ui.Paint()
      ..color = AppColors.electricCyan.withAlpha(70)
      ..strokeWidth = 6.0
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;

    final bonePaint = ui.Paint()
      ..color = AppColors.electricCyan
      ..strokeWidth = 3.5
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;

    final highConfidenceJointPaint = ui.Paint()
      ..color = AppColors.voltLime
      ..style = ui.PaintingStyle.fill;

    final normalJointPaint = ui.Paint()
      ..color = AppColors.electricCyan
      ..style = ui.PaintingStyle.fill;
    final targetJointGlowPaint = ui.Paint()
      ..color = AppColors.energyOrange.withAlpha(85)
      ..style = ui.PaintingStyle.fill;
    final targetJointRingPaint = ui.Paint()
      ..color = AppColors.energyOrange
      ..strokeWidth = 2.5
      ..style = ui.PaintingStyle.stroke;

    final jointBorderPaint = ui.Paint()
      ..color = AppColors.obsidian
      ..strokeWidth = 2.0
      ..style = ui.PaintingStyle.stroke;

    // 1. Draw all detected bones; each exercise's measured joint stays highlighted.
    for (final connection in _connections) {
      final first = frame.landmarks[connection.$1];
      final second = frame.landmarks[connection.$2];
      if (first != null &&
          second != null &&
          first.isValid &&
          second.isValid &&
          first.confidence >= 0.35 &&
          second.confidence >= 0.35) {
        final p1 = point(first);
        final p2 = point(second);
        canvas.drawLine(p1, p2, glowPaint);
        canvas.drawLine(p1, p2, bonePaint);
      }
    }

    // 2. Draw every valid detected landmark and suppress low-confidence noise.
    for (final landmark in frame.landmarks.values) {
      if (!landmark.isValid || landmark.confidence < 0.35) continue;
      final pt = point(landmark);
      final isHigh = landmark.confidence >= 0.65;
      final radius = isHigh ? 6.0 : 4.5;
      final isTargetJoint = _primaryLandmarks.contains(landmark.name);

      if (isTargetJoint) {
        canvas.drawCircle(pt, radius + 7, targetJointGlowPaint);
        canvas.drawCircle(pt, radius + 3, targetJointRingPaint);
      }

      canvas.drawCircle(
        pt,
        radius,
        isHigh ? highConfidenceJointPaint : normalJointPaint,
      );
      canvas.drawCircle(pt, radius, jointBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LivePoseSkeletonPainter oldDelegate) =>
      oldDelegate.frame.timestamp != frame.timestamp ||
      oldDelegate.exerciseId != exerciseId ||
      oldDelegate.isFrontCamera != isFrontCamera;

  Set<String> get _primaryLandmarks => switch (exerciseId) {
    'squat' || 'lunge' => const {'leftKnee', 'rightKnee'},
    'shoulder_flexion' || 'shoulder_abduction' => const {
      'leftShoulder', 'rightShoulder',
    },
    'calf_raise' => const {'leftAnkle', 'rightAnkle'},
    'hip_hinge' || 'balance' => const {'leftHip', 'rightHip'},
    'elbow_flexion' || 'push_up' => const {'leftElbow', 'rightElbow'},
    _ => const <String>{},
  };
}

class _SportsViewfinderBackground extends StatelessWidget {
  const _SportsViewfinderBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Color(0xFF0F151C)),
      child: CustomPaint(painter: _GridPatternPainter()),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()
      ..color = AppColors.borderDivider.withAlpha(60)
      ..strokeWidth = 1.0;

    for (double y = 40; y < size.height; y += 40) {
      canvas.drawLine(ui.Offset(0, y), ui.Offset(size.width, y), paint);
    }
    for (double x = 40; x < size.width; x += 40) {
      canvas.drawLine(ui.Offset(x, 0), ui.Offset(x, size.height), paint);
    }

    final crosshairPaint = ui.Paint()
      ..color = AppColors.electricCyan.withAlpha(80)
      ..strokeWidth = 1.5;
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.drawLine(
      ui.Offset(cx - 20, cy),
      ui.Offset(cx + 20, cy),
      crosshairPaint,
    );
    canvas.drawLine(
      ui.Offset(cx, cy - 20),
      ui.Offset(cx, cy + 20),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TelemetryCategoryChip extends StatelessWidget {
  const _TelemetryCategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.electricCyan.withAlpha(50)
              : AppColors.obsidian.withAlpha(160),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.electricCyan
                : AppColors.borderDivider,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.electricCyan
                : AppColors.textSecondary,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _DetailedTelemetryScrollCard extends StatelessWidget {
  const _DetailedTelemetryScrollCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.obsidian.withAlpha(190),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDivider.withAlpha(140)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: color,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}
