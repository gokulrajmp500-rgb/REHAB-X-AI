import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../domain/services/trend_analysis_service.dart';
import '../theme/app_theme.dart';

// ==========================================
// 1. SCREEN 2: READINESS COCKPIT CARD
// ==========================================

class AthleteReadinessCockpitCard extends StatelessWidget {
  const AthleteReadinessCockpitCard({
    super.key,
    this.readinessScore = 82,
    this.movementScore = 85,
    this.recoveryScore = 78,
    this.consistencyScore = 88,
  });

  final double readinessScore;
  final double movementScore;
  final double recoveryScore;
  final double consistencyScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Row(
        children: [
          // Left: Circular Readiness Gauge (Volt Lime & Electric Cyan)
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(120, 120),
                  painter: _ReadinessRingPainter(score: readinessScore),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'READINESS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${readinessScore.toInt()}%',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.0,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Right: 3 Key Breakdown Metrics
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ReadinessMetricRow(
                  label: 'Movement',
                  value: '${movementScore.toInt()}%',
                  dotColor: AppColors.electricCyan,
                ),
                const SizedBox(height: 12),
                _ReadinessMetricRow(
                  label: 'Recovery',
                  value: '${recoveryScore.toInt()}%',
                  dotColor: AppColors.voltLime,
                ),
                const SizedBox(height: 12),
                _ReadinessMetricRow(
                  label: 'Consistency',
                  value: '${consistencyScore.toInt()}%',
                  dotColor: AppColors.electricCyan,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessMetricRow extends StatelessWidget {
  const _ReadinessMetricRow({
    required this.label,
    required this.value,
    required this.dotColor,
  });

  final String label;
  final String value;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withAlpha(120),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: dotColor,
          ),
        ),
      ],
    );
  }
}

class _ReadinessRingPainter extends CustomPainter {
  _ReadinessRingPainter({required this.score});
  final double score;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;

    const startAngle = -math.pi / 2;
    const sweepTotal = math.pi * 2;
    final currentSweep = sweepTotal * (score.clamp(0, 100) / 100.0);

    final trackPaint = Paint()
      ..color = AppColors.titanium
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      sweepTotal,
      false,
      trackPaint,
    );

    final activePaint = Paint()
      ..shader = const SweepGradient(
        colors: [AppColors.electricCyan, AppColors.voltLime, AppColors.electricCyan],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      currentSweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReadinessRingPainter oldDelegate) => oldDelegate.score != score;
}

// ==========================================
// 2. SCREEN 2: TODAY'S FOCUS CARD
// ==========================================

class TodaysFocusCard extends StatelessWidget {
  const TodaysFocusCard({
    super.key,
    this.tag = "TODAY'S FOCUS",
    this.title = 'Lower-body stability',
    this.description = 'Focus on controlled movement and consistent form.',
    required this.onStartSession,
  });

  final String tag;
  final String title;
  final String description;
  final VoidCallback onStartSession;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.electricCyan,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Vector wireframe runner icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.carbon,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDivider),
                ),
                child: const Icon(
                  Icons.accessibility_new,
                  color: AppColors.electricCyan,
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Flagship Electric Cyan Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onStartSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.electricCyan,
                foregroundColor: AppColors.obsidian,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'START SESSION',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. SCREEN 2: PERFORMANCE MINDSET PANEL
// ==========================================

class PerformanceMindsetPanel extends StatelessWidget {
  const PerformanceMindsetPanel({
    super.key,
    this.focusScore = 82,
    this.consistencyScore = 91,
    this.disciplineScore = 76,
    this.recoveryAwarenessScore = 68,
  });

  final double focusScore;
  final double consistencyScore;
  final double disciplineScore;
  final double recoveryAwarenessScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PERFORMANCE MINDSET',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 16),
          _MindsetRow(
            icon: Icons.bolt,
            label: 'Focus',
            value: focusScore,
            color: AppColors.electricCyan,
          ),
          const SizedBox(height: 14),
          _MindsetRow(
            icon: Icons.track_changes,
            label: 'Consistency',
            value: consistencyScore,
            color: AppColors.voltLime,
          ),
          const SizedBox(height: 14),
          _MindsetRow(
            icon: Icons.fitness_center,
            label: 'Training Discipline',
            value: disciplineScore,
            color: AppColors.statusAttention,
          ),
          const SizedBox(height: 14),
          _MindsetRow(
            icon: Icons.refresh,
            label: 'Recovery Awareness',
            value: recoveryAwarenessScore,
            color: AppColors.energyOrange,
          ),
        ],
      ),
    );
  }
}

class _MindsetRow extends StatelessWidget {
  const _MindsetRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 13),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 100.0).clamp(0.0, 1.0),
              backgroundColor: AppColors.titanium,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 34,
          child: Text(
            '${value.toInt()}%',
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 4. SCREEN 3: CAMERA ANALYSIS BOTTOM HUD
// ==========================================

class CameraAnalysisHUDCard extends StatelessWidget {
  const CameraAnalysisHUDCard({
    super.key,
    required this.reps,
    required this.formQuality,
    required this.confidence,
    required this.sessionTime,
    required this.qualityScore,
  });

  final int reps;
  final String formQuality;
  final double confidence;
  final String sessionTime;
  final int qualityScore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.obsidian.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _HUDMetricColumn(
                label: 'REP',
                value: reps.toString().padLeft(2, '0'),
                valueColor: AppColors.textPrimary,
              ),
              _HUDMetricColumn(
                label: 'FORM',
                value: formQuality.toUpperCase(),
                valueColor: AppColors.voltLime,
              ),
              _HUDMetricColumn(
                label: 'CONFIDENCE',
                value: '${confidence.toInt()}%',
                valueColor: AppColors.electricCyan,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppColors.borderDivider, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SESSION',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  Text(
                    sessionTime,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.carbon,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.electricCyan.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    Text(
                      '$qualityScore',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.electricCyan),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'QUALITY',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HUDMetricColumn extends StatelessWidget {
  const _HUDMetricColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: valueColor),
        ),
      ],
    );
  }
}

// ==========================================
// 5. SCREEN 4: RESULTS SCREEN COMPONENTS
// ==========================================

class MovementQualityGauge extends StatelessWidget {
  const MovementQualityGauge({
    super.key,
    required this.score,
  });

  final double? score;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(160, 160),
              painter: ResultsQualityRingPainter(score: score ?? 0),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  score == null ? '--' : score!.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -1.5,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'MOVEMENT\nQUALITY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ResultsQualityRingPainter extends CustomPainter {
  ResultsQualityRingPainter({required this.score});
  final double score;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;

    const startAngle = -math.pi / 2;
    const sweepTotal = math.pi * 2;
    final currentSweep = sweepTotal * (score.clamp(0, 100) / 100.0);

    final trackPaint = Paint()
      ..color = AppColors.titanium
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      sweepTotal,
      false,
      trackPaint,
    );

    final activePaint = Paint()
      ..shader = const SweepGradient(
        colors: [AppColors.voltLime, AppColors.electricCyan, AppColors.voltLime],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      currentSweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ResultsQualityRingPainter oldDelegate) => oldDelegate.score != score;
}

class ResultsSummaryRow extends StatelessWidget {
  const ResultsSummaryRow({
    super.key,
    required this.rom,
    required this.consistency,
    required this.confidence,
    required this.repetitions,
  });

  final double? rom;
  final double? consistency;
  final double? confidence;
  final int? repetitions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: ResultStatBox(label: 'ROM', value: rom == null ? '--' : '${rom!.toStringAsFixed(0)}°', valueColor: AppColors.electricCyan)),
        const SizedBox(width: 8),
        Expanded(child: ResultStatBox(label: 'Consistency', value: consistency == null ? '--' : '${consistency!.toStringAsFixed(0)}%', valueColor: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Expanded(child: ResultStatBox(label: 'Confidence', value: confidence == null ? '--' : '${confidence!.toStringAsFixed(0)}%', valueColor: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Expanded(child: ResultStatBox(label: 'Repetitions', value: repetitions?.toString() ?? '--', valueColor: AppColors.textPrimary)),
      ],
    );
  }
}

class ResultStatBox extends StatelessWidget {
  const ResultStatBox({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class KeyObservationsCard extends StatelessWidget {
  const KeyObservationsCard({
    super.key,
    required this.observations,
  });

  final List<String> observations;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KEY OBSERVATIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < observations.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? AppColors.voltLime
                          : (i == 1 ? AppColors.electricCyan : AppColors.energyOrange),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    observations[i],
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4),
                  ),
                ),
              ],
            ),
            if (i < observations.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// 6. SCREEN 5: AI COACH INSIGHT CARDS & WAVE
// ==========================================

class AiCoachInsightCard extends StatelessWidget {
  const AiCoachInsightCard({
    super.key,
    required this.title,
    required this.content,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String content;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withAlpha(90)),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AiWaveformVisualizer extends StatelessWidget {
  const AiWaveformVisualizer({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 90,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(280, 80),
              painter: _WaveformPainter(),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.obsidian,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.electricCyan, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.electricCyan.withAlpha(120),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.psychology,
                  color: AppColors.electricCyan,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.electricCyan.withAlpha(140)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final midY = size.height / 2;
    path.moveTo(0, midY);

    for (double x = 0; x <= size.width; x += 1) {
      final norm = (x / size.width) * 4 * math.pi;
      final envelope = math.sin(x / size.width * math.pi);
      final y = midY + math.sin(norm * 2) * 18 * envelope;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==========================================
// 7. SCREEN 6: TODAY'S PLAN TIMELINE ITEM
// ==========================================

class PlanTimelineItem extends StatelessWidget {
  const PlanTimelineItem({
    super.key,
    required this.index,
    required this.title,
    required this.duration,
    required this.difficulty,
    required this.description,
    this.isCompleted = false,
    this.isActive = false,
  });

  final int index;
  final String title;
  final String duration;
  final String difficulty;
  final String description;
  final bool isCompleted;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final accent = isCompleted
        ? AppColors.voltLime
        : (isActive ? AppColors.electricCyan : AppColors.textSecondary);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.electricCyan : AppColors.borderDivider,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Index Badge / Circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(color: accent),
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check, size: 16, color: accent)
                  : Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Exercise info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      duration,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.titanium,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        difficulty,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Right status indicator
          Icon(
            isCompleted
                ? Icons.check_circle
                : (isActive ? Icons.play_circle_filled : Icons.radio_button_unchecked),
            color: accent,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 8. SCREEN 7: RECOVERY DASHBOARD COMPONENTS
// ==========================================

class RecoveryTrendBarChart extends StatelessWidget {
  const RecoveryTrendBarChart({
    super.key,
    required this.sessionCounts,
    required this.dayLabels,
  });

  final List<int> sessionCounts;
  final List<String> dayLabels;

  @override
  Widget build(BuildContext context) {
    assert(sessionCounts.length == dayLabels.length);
    final maxCount = sessionCounts.fold<int>(0, math.max);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECORDED MOVEMENT · LAST 7 DAYS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < sessionCounts.length; i++)
                Column(
                  children: [
                    Text(
                      '${sessionCounts[i]}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 18,
                      height: maxCount == 0
                          ? 4
                          : (sessionCounts[i] / maxCount * 76)
                              .clamp(4.0, 76.0),
                      decoration: BoxDecoration(
                        color: AppColors.electricCyan.withAlpha(160),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dayLabels[i],
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 9. SCREEN 8: PROGRESS DASHBOARD COMPONENTS
// ==========================================

class MovementQualityTrendLineChart extends StatelessWidget {
  const MovementQualityTrendLineChart({
    super.key,
    required this.points,
  });

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MOVEMENT CONSISTENCY TREND',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textSecondary, letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.voltLime.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  points.isEmpty
                      ? 'N/A'
                      : '${points.map((point) => point.value).reduce(math.max).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.voltLime),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: CustomPaint(
              size: const Size(double.infinity, 100),
              painter: _TrendLinePainter(points),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: points.map((point) => Text(
              '${point.timestamp.month}/${point.timestamp.day}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  _TrendLinePainter(this.points);
  final List<TrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.titanium
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.50), Offset(size.width, size.height * 0.50), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), gridPaint);

    final linePaint = Paint()
      ..color = AppColors.electricCyan
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (points.length < 2) return;
    final values = points.map((point) => point.value).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = (maxValue - minValue).abs() < 0.001
        ? 1.0
        : maxValue - minValue;
    final chartPoints = List<Offset>.generate(points.length, (index) {
      final x = index / (points.length - 1) * size.width;
      final y = size.height -
          ((values[index] - minValue) / range * (size.height - 16)) -
          8;
      return Offset(x, y);
    });

    final path = Path();
    path.moveTo(chartPoints.first.dx, chartPoints.first.dy);
    for (var i = 1; i < chartPoints.length; i++) {
      path.lineTo(chartPoints[i].dx, chartPoints[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Peak dot
    final dotPaint = Paint()
      ..color = AppColors.voltLime
      ..style = PaintingStyle.fill;
    for (final point in chartPoints) {
      canvas.drawCircle(point, 4.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) =>
      oldDelegate.points != points;
}

// ==========================================
// 10. REUSABLE ATHLETE OS COMPONENTS
// ==========================================

class AthletePerformanceGauge extends StatelessWidget {
  const AthletePerformanceGauge({
    super.key,
    required this.score,
    this.label = 'READINESS',
    this.status = 'PEAK READINESS',
    this.subtext = 'Optimal neural & biomechanical drive',
    this.size = 180,
  });

  final double score;
  final String label;
  final String status;
  final String subtext;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _GaugeArcPainter(score: score),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${score.toInt()}%',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -1.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.electricCyan,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: score >= 80 ? AppColors.voltLime : AppColors.electricCyan,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: score >= 80 ? AppColors.voltLime : AppColors.electricCyan,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GaugeArcPainter extends CustomPainter {
  _GaugeArcPainter({required this.score});
  final double score;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;

    const startAngle = 135 * (math.pi / 180);
    const sweepTotal = 270 * (math.pi / 180);
    final currentSweep = sweepTotal * (score.clamp(0, 100) / 100.0);

    final trackPaint = Paint()
      ..color = AppColors.titanium
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    final arcPaint = Paint()
      ..shader = const SweepGradient(
        colors: [AppColors.electricCyan, AppColors.voltLime],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      currentSweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugeArcPainter oldDelegate) => oldDelegate.score != score;
}

class QuickActionButton extends StatelessWidget {
  const QuickActionButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.accentColor = AppColors.electricCyan,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isPrimary ? accentColor.withAlpha(22) : AppColors.graphite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPrimary ? accentColor.withAlpha(160) : AppColors.borderDivider,
              width: isPrimary ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isPrimary ? accentColor : AppColors.titanium,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isPrimary ? AppColors.obsidian : accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isPrimary ? accentColor : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 13, color: isPrimary ? accentColor : AppColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

class BodySilhouetteAlignmentGuide extends StatelessWidget {
  const BodySilhouetteAlignmentGuide({
    super.key,
    required this.isAligned,
    required this.alignmentProgress,
    this.cue = 'STEP INTO THE SILHOUETTE',
  });

  final bool isAligned;
  final double alignmentProgress;
  final String cue;

  @override
  Widget build(BuildContext context) {
    final activeColor = isAligned
        ? AppColors.voltLime
        : (alignmentProgress > 0.5 ? AppColors.electricCyan : AppColors.energyOrange);

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _AthleticSilhouettePainter(
              color: activeColor,
              isAligned: isAligned,
            ),
          ),
          Positioned(
            bottom: 48,
            left: 20,
            right: 20,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.obsidian.withAlpha(210),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: activeColor.withAlpha(180), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAligned ? Icons.check_circle : Icons.accessibility_new,
                      color: activeColor,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        cue.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: activeColor,
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AthleticSilhouettePainter extends CustomPainter {
  _AthleticSilhouettePainter({
    required this.color,
    required this.isAligned,
  });

  final Color color;
  final bool isAligned;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final outlinePaint = Paint()
      ..color = color.withAlpha(isAligned ? 120 : 60)
      ..strokeWidth = isAligned ? 2.5 : 1.5
      ..style = PaintingStyle.stroke;

    // Head
    canvas.drawCircle(Offset(w * 0.5, h * 0.16), h * 0.06, outlinePaint);

    // Torso
    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.38), width: w * 0.38, height: h * 0.28),
      const Radius.circular(16),
    );
    canvas.drawRRect(torsoRect, outlinePaint);

    // Arms
    canvas.drawLine(Offset(w * 0.28, h * 0.28), Offset(w * 0.20, h * 0.48), outlinePaint);
    canvas.drawLine(Offset(w * 0.72, h * 0.28), Offset(w * 0.80, h * 0.48), outlinePaint);

    // Legs
    canvas.drawLine(Offset(w * 0.40, h * 0.52), Offset(w * 0.36, h * 0.84), outlinePaint);
    canvas.drawLine(Offset(w * 0.60, h * 0.52), Offset(w * 0.64, h * 0.84), outlinePaint);
  }

  @override
  bool shouldRepaint(covariant _AthleticSilhouettePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isAligned != isAligned;
}

class TelemetryBadge extends StatelessWidget {
  const TelemetryBadge({
    super.key,
    required this.title,
    required this.value,
    this.unit = '',
    this.color = AppColors.electricCyan,
    this.subtext,
  });

  final String title;
  final String value;
  final String unit;
  final Color color;
  final String? subtext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.obsidian.withAlpha(200),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
