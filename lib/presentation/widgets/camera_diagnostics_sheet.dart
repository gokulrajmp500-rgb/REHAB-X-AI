import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/sports_glass_card.dart';
import '../../domain/services/analysis_session_controller.dart';

class CameraDiagnosticsSheet extends StatelessWidget {
  const CameraDiagnosticsSheet({
    super.key,
    required this.diagnostics,
    required this.exerciseName,
    required this.requiredLandmarks,
  });

  final CameraDiagnostics diagnostics;
  final String exerciseName;
  final List<String> requiredLandmarks;

  static void show(
    BuildContext context, {
    required CameraDiagnostics diagnostics,
    required String exerciseName,
    required List<String> requiredLandmarks,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CameraDiagnosticsSheet(
        diagnostics: diagnostics,
        exerciseName: exerciseName,
        requiredLandmarks: requiredLandmarks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validRatio = diagnostics.totalFrames > 0
        ? (diagnostics.validFrames / diagnostics.totalFrames * 100).toStringAsFixed(1)
        : '0.0';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: AppColors.cyan, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'TECHNICAL DIAGNOSTICS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.cyan,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SportsGlassCard(
              child: Column(
                children: [
                  _DiagRow(label: 'Exercise', value: exerciseName),
                  _DiagRow(label: 'Camera Frame Rate', value: '${diagnostics.fps.toStringAsFixed(1)} FPS'),
                  _DiagRow(label: 'Pose Tracking Rate', value: '${diagnostics.poseFps.toStringAsFixed(1)} FPS'),
                  _DiagRow(label: 'Processing Latency', value: '${diagnostics.latencyMs} ms'),
                  _DiagRow(label: 'Valid Frame Ratio', value: '$validRatio%'),
                  _DiagRow(
                    label: 'Mean Confidence',
                    value: '${(diagnostics.averageConfidence * 100).toStringAsFixed(0)}%',
                  ),
                  _DiagRow(label: 'Total Frames Received', value: '${diagnostics.totalFrames}'),
                  _DiagRow(label: 'Dropped / Throttled Frames', value: '${diagnostics.droppedFrames}'),
                  _DiagRow(label: 'Resolution', value: diagnostics.imageResolution),
                  _DiagRow(label: 'Required Joints', value: requiredLandmarks.join(', ')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

