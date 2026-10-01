import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/sports_glass_card.dart';
import '../../data/models/exercise.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/video_analysis_service.dart';
import '../../domain/services/exercise_analyzers.dart';

class RecordedVideoAnalysisPage extends StatefulWidget {
  const RecordedVideoAnalysisPage({super.key, required this.exercise});

  final Exercise exercise;

  @override
  State<RecordedVideoAnalysisPage> createState() => _RecordedVideoAnalysisPageState();
}

class _RecordedVideoAnalysisPageState extends State<RecordedVideoAnalysisPage> {
  final _videoService = const VideoAnalysisService();
  String _selectedVideoSource = 'gallery_capture_01.mp4';
  bool _isProcessing = false;
  VideoAnalysisProgress? _currentProgress;
  VideoAnalysisResult? _analysisResult;
  String? _errorMessage;
  VideoTimelineMarker? _selectedMarker;

  final List<String> _sampleVideos = [
    'gallery_capture_01.mp4',
    'squat_technique_assessment.mp4',
    'lunge_symmetry_evaluation.mp4',
    'custom_athlete_recording.mp4',
  ];

  Future<void> _startVideoAnalysis() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _analysisResult = null;
      _selectedMarker = null;
    });

    final analyzer = getExerciseAnalyzer(widget.exercise.id) ?? const SquatAnalyzer();

    try {
      final result = await _videoService.analyzeVideo(
        videoPath: _selectedVideoSource,
        exerciseId: widget.exercise.id,
        exerciseName: widget.exercise.name,
        athleteId: 'athlete',
        analyzer: analyzer,
        onProgress: (p) {
          if (mounted) setState(() => _currentProgress = p);
        },
      );

      // Save the resulting session to the session repository
      final prefs = await SharedPreferences.getInstance();
      await LocalSessionRepository(prefs).create(result.session);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _analysisResult = result;
          if (result.timelineMarkers.isNotEmpty) {
            _selectedMarker = result.timelineMarkers.first;
          }
        });
      }
    } on VideoAnalysisException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Video analysis could not be completed. Check video format.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.exercise.name} - Video Analysis'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(
            children: [
              const SportsChip(label: 'MODE B: RECORDED VIDEO', color: AppColors.cyan, icon: Icons.video_library),
              const Spacer(),
              Text(
                _isProcessing ? 'PROCESSING' : _analysisResult != null ? 'COMPLETE' : 'READY',
                style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Video Selector Card
          SportsGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Video from Gallery / Storage', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedVideoSource,
                  decoration: const InputDecoration(
                    labelText: 'Video Source',
                    prefixIcon: Icon(Icons.file_present_outlined, color: AppColors.cyan),
                  ),
                  items: _sampleVideos
                      .map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: _isProcessing ? null : (val) => setState(() => _selectedVideoSource = val!),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _isProcessing ? null : _startVideoAnalysis,
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(_isProcessing ? 'Analyzing Frames...' : 'Start Video Analysis'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size(double.infinity, 46),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Progress Card while analyzing
          if (_isProcessing && _currentProgress != null) ...[
            SportsGlassCard(
              borderColor: AppColors.cyan.withAlpha(120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hourglass_top, color: AppColors.cyan, size: 18),
                      const SizedBox(width: 8),
                      const Text('Analyzing movement...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Text(
                        '${(_currentProgress!.percentage * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Frame ${_currentProgress!.currentFrame} / ${_currentProgress!.totalFrames}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentProgress!.currentStage,
                    style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _currentProgress!.percentage,
                      color: AppColors.cyan,
                      backgroundColor: AppColors.line,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Error card
          if (_errorMessage != null) ...[
            SportsGlassCard(
              borderColor: AppColors.coral,
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.coral),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_errorMessage!, style: const TextStyle(color: AppColors.coral, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Results Section
          if (_analysisResult != null) ...[
            SportsGlassCard(
              borderColor: AppColors.green.withAlpha(150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SportsChip(label: 'ANALYSIS COMPLETE', color: AppColors.green, icon: Icons.check_circle),
                      const Spacer(),
                      Text(
                        '${_analysisResult!.totalFrames} frames analyzed',
                        style: const TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _StatMini(
                          label: 'REPETITIONS',
                          value: '${_analysisResult!.session.metrics.repetitions}',
                          color: AppColors.green,
                        ),
                      ),
                      Expanded(
                        child: _StatMini(
                          label: 'ROM',
                          value: '${_analysisResult!.session.metrics.rangeOfMotion.toStringAsFixed(0)}°',
                          color: AppColors.cyan,
                        ),
                      ),
                      Expanded(
                        child: _StatMini(
                          label: 'CONSISTENCY',
                          value: '${_analysisResult!.session.metrics.consistency.toStringAsFixed(0)}%',
                          color: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Video Timeline Analysis (Requirement 12)
            const Text(
              'Video Timeline Analysis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap repetition markers along the video timeline to inspect kinematics.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),

            SportsGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('00:00', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                      Text(
                        '${(_analysisResult!.videoDurationSeconds).toStringAsFixed(1)}s',
                        style: const TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Stack(
                      children: _analysisResult!.timelineMarkers.map((marker) {
                        final ratio = (marker.timestampSeconds / _analysisResult!.videoDurationSeconds).clamp(0.05, 0.95);
                        final isSel = _selectedMarker?.repNumber == marker.repNumber;
                        return Positioned(
                          left: ratio * 280,
                          top: 1,
                          child: InkWell(
                            onTap: () => setState(() => _selectedMarker = marker),
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: marker.hasVariation ? AppColors.orange : (isSel ? AppColors.green : AppColors.cyan),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Marker details
                  if (_selectedMarker != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.panelLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _selectedMarker!.label,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.cyan),
                              ),
                              const Spacer(),
                              Text(
                                '@ ${_selectedMarker!.timestampSeconds.toStringAsFixed(1)}s in video',
                                style: const TextStyle(color: AppColors.muted, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('Range of motion: ${_selectedMarker!.rangeOfMotion.toStringAsFixed(0)}°'),
                              const Spacer(),
                              Text('Tempo: ${_selectedMarker!.tempo.toStringAsFixed(1)}s'),
                            ],
                          ),
                          if (_selectedMarker!.hasVariation) ...[
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Icon(Icons.warning_amber, size: 14, color: AppColors.orange),
                                SizedBox(width: 4),
                                Text(
                                  'Movement variation detected in this repetition',
                                  style: TextStyle(color: AppColors.orange, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text('Save and Return to Dashboard'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cyan,
                foregroundColor: AppColors.ink,
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
