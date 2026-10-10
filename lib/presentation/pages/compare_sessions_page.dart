import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/sports_glass_card.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models/pose_models.dart';
import '../../domain/services/progress_service.dart';

class CompareSessionsPage extends StatefulWidget {
  const CompareSessionsPage({super.key, this.initialSessionA, this.initialSessionB});

  final SessionRecord? initialSessionA;
  final SessionRecord? initialSessionB;

  @override
  State<CompareSessionsPage> createState() => _CompareSessionsPageState();
}

class _CompareSessionsPageState extends State<CompareSessionsPage> {
  List<SessionRecord> _sessions = [];
  SessionRecord? _sessionA;
  SessionRecord? _sessionB;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = verifiedMovementSessions(
      await LocalSessionRepository(prefs).readAll('athlete'),
    );
    if (mounted) {
      setState(() {
        _sessions = list;
        _isLoading = false;
        if (widget.initialSessionA != null) {
          _sessionA = widget.initialSessionA;
        } else if (list.isNotEmpty) {
          _sessionA = list.first;
        }
        if (widget.initialSessionB != null) {
          _sessionB = widget.initialSessionB;
        } else if (list.length > 1) {
          _sessionB = list[1];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_sessions.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compare Sessions')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: SportsGlassCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.compare_arrows, color: AppColors.muted, size: 28),
                SizedBox(height: 12),
                Text('Insufficient Data for Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 6),
                Text('At least two completed movement sessions are required to perform comparative kinematic analysis.'),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Comparison'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Row(
            children: [
              SportsChip(label: 'KINEMATIC COMPARISON', color: AppColors.cyan, icon: Icons.compare_arrows),
              Spacer(),
              Text('SIDE-BY-SIDE EVALUATION', style: TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),

          // Selectors
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SESSION A (LATER)', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<SessionRecord>(
                      initialValue: _sessionA,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: _sessions.map((s) => DropdownMenuItem(value: s, child: Text('${s.exercise} (${_shortDate(s.timestamp)})', style: const TextStyle(fontSize: 11.5)))).toList(),
                      onChanged: (val) => setState(() => _sessionA = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SESSION B (EARLIER)', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<SessionRecord>(
                      initialValue: _sessionB,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: _sessions.map((s) => DropdownMenuItem(value: s, child: Text('${s.exercise} (${_shortDate(s.timestamp)})', style: const TextStyle(fontSize: 11.5)))).toList(),
                      onChanged: (val) => setState(() => _sessionB = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_sessionA != null && _sessionB != null) ...[
            _ComparisonTile(
              metricName: 'Range of Motion (ROM)',
              valA: _sessionA!.metrics.rangeOfMotion,
              valB: _sessionB!.metrics.rangeOfMotion,
              unit: '°',
              higherIsBetter: true,
            ),
            const SizedBox(height: 10),
            _ComparisonTile(
              metricName: 'Movement Consistency',
              valA: _sessionA!.metrics.consistency,
              valB: _sessionB!.metrics.consistency,
              unit: '%',
              higherIsBetter: true,
            ),
            const SizedBox(height: 10),
            _ComparisonTile(
              metricName: 'Repetitions Tracked',
              valA: _sessionA!.metrics.repetitions.toDouble(),
              valB: _sessionB!.metrics.repetitions.toDouble(),
              unit: ' reps',
              higherIsBetter: true,
            ),
            const SizedBox(height: 10),
            _ComparisonTile(
              metricName: 'Pose Confidence',
              valA: _sessionA!.metrics.dataConfidence * 100,
              valB: _sessionB!.metrics.dataConfidence * 100,
              unit: '%',
              higherIsBetter: true,
            ),
            const SizedBox(height: 10),
            _ComparisonTile(
              metricName: 'Bilateral Asymmetry',
              valA: _sessionA!.metrics.symmetry,
              valB: _sessionB!.metrics.symmetry,
              unit: '%',
              higherIsBetter: false,
            ),
            const SizedBox(height: 20),

            // Summary observation card
            SportsGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('COMPARISON SUMMARY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.muted, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Text(
                    _sessionA!.id == _sessionB!.id
                        ? 'Select two distinct sessions for comparative analysis.'
                        : 'Comparing ${_sessionA!.exercise} on ${_shortDate(_sessionA!.timestamp)} against ${_sessionB!.exercise} on ${_shortDate(_sessionB!.timestamp)}.\nDifferences are calculated strictly from recorded pose angles and kinematics.',
                    style: const TextStyle(fontSize: 13, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Comparative movement metrics indicate kinematic variations and are not clinical progress certifications.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime d) => '${d.month}/${d.day}';
}

class _ComparisonTile extends StatelessWidget {
  const _ComparisonTile({
    required this.metricName,
    required this.valA,
    required this.valB,
    required this.unit,
    required this.higherIsBetter,
  });

  final String metricName;
  final double? valA;
  final double? valB;
  final String unit;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    if (valA == null || valB == null) {
      return SportsGlassCard(
        child: Row(
          children: [
            Text(metricName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            const SportsChip(label: 'INSUFFICIENT DATA', color: AppColors.muted),
          ],
        ),
      );
    }

    final delta = valA! - valB!;
    final isDeltaZero = delta.abs() < 0.5;
    final isPositiveGood = higherIsBetter ? delta > 0 : delta < 0;

    final (statusLabel, statusColor) = isDeltaZero
        ? ('STABLE', AppColors.cyan)
        : isPositiveGood
            ? ('IMPROVED', AppColors.green)
            : ('REDUCED', AppColors.orange);

    return SportsGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(metricName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const Spacer(),
              SportsChip(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session A: ${valA!.toStringAsFixed(1)}$unit',
                style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.bold),
              ),
              Text(
                'Session B: ${valB!.toStringAsFixed(1)}$unit',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              Text(
                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}$unit',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: statusColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
