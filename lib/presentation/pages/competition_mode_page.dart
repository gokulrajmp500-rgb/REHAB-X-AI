import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/sports_glass_card.dart';
import '../../data/models/competition.dart';
import '../../data/repositories/local_rehab_repository.dart';

class CompetitionModePage extends StatefulWidget {
  const CompetitionModePage({super.key});

  @override
  State<CompetitionModePage> createState() => _CompetitionModePageState();
}

class _CompetitionModePageState extends State<CompetitionModePage> {
  CompetitionEvent? _competition;
  List<PreCompetitionChecklistItem> _checklist = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalRehabRepository(prefs);
    final comp = await repo.loadCompetition();
    final list = await repo.loadCompetitionChecklist();
    if (mounted) {
      setState(() {
        _competition = comp;
        _checklist = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleChecklist(String id) async {
    final updated = _checklist.map((item) {
      return item.id == id ? item.copyWith(completed: !item.completed) : item;
    }).toList();

    setState(() => _checklist = updated);
    final prefs = await SharedPreferences.getInstance();
    await LocalRehabRepository(prefs).saveCompetitionChecklist(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final comp = _competition!;
    final completedCount = _checklist.where((c) => c.completed).length;
    final progress = _checklist.isEmpty ? 0.0 : completedCount / _checklist.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Competition Mode'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            children: [
              const SportsChip(label: 'COMPETITION PREPARATION', color: AppColors.orange, icon: Icons.emoji_events_outlined),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% READY',
                style: const TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Competition Event Overview Card
          SportsGlassCard(
            borderColor: AppColors.orange.withAlpha(120),
            gradient: const LinearGradient(
              colors: [Color(0xFF241C10), Color(0xFF141922)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comp.name,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const SizedBox(height: 6),
                Text(
                  '${comp.sport} · ${comp.event}',
                  style: const TextStyle(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _CompInfo(label: 'Date', value: '${comp.date.year}-${comp.date.month.toString().padLeft(2, '0')}-${comp.date.day.toString().padLeft(2, '0')}'),
                    ),
                    Expanded(
                      child: _CompInfo(label: 'Reporting Time', value: comp.reportingTime),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CompInfo(label: 'Start Time', value: comp.startTime),
                    ),
                    Expanded(
                      child: _CompInfo(label: 'Travel Time', value: comp.travelTime),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 6),
                _CompInfo(label: 'Venue', value: '${comp.venue} (${comp.venueAddress})'),
                const SizedBox(height: 8),
                _CompInfo(label: 'Equipment Required', value: comp.equipment),
                const SizedBox(height: 8),
                _CompInfo(label: 'Event Instructions', value: comp.instructions),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Progression Flow
          const Text(
            'Preparation Timeline',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                _StepBadge(label: 'Preparation', isDone: true),
                _Arrow(),
                _StepBadge(label: 'Training', isDone: true),
                _Arrow(),
                _StepBadge(label: 'Checklist', isDone: false, isActive: true),
                _Arrow(),
                _StepBadge(label: 'Travel', isDone: false),
                _Arrow(),
                _StepBadge(label: 'Warm-Up', isDone: false),
                _Arrow(),
                _StepBadge(label: 'Competition', isDone: false),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Smart Pre-Competition Checklist (Requirement 29)
          Row(
            children: [
              const Text(
                'Pre-Competition Checklist',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '$completedCount of ${_checklist.length} completed',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              color: AppColors.green,
              backgroundColor: AppColors.line,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),

          ..._checklist.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SportsGlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  borderColor: item.completed ? AppColors.green.withAlpha(80) : AppColors.line,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.green,
                    checkColor: AppColors.ink,
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: item.completed ? TextDecoration.lineThrough : null,
                        color: item.completed ? AppColors.muted : AppColors.text,
                      ),
                    ),
                    subtitle: Text(
                      item.category.toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: AppColors.muted, letterSpacing: 0.6),
                    ),
                    value: item.completed,
                    onChanged: (_) => _toggleChecklist(item.id),
                  ),
                ),
              )),
          const SizedBox(height: 12),
          const Text(
            'Checklist status is persisted locally. Travel times reflect athlete-configured estimates.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _CompInfo extends StatelessWidget {
  const _CompInfo({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.label, required this.isDone, this.isActive = false});
  final String label;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? AppColors.green
        : isActive
            ? AppColors.cyan
            : AppColors.muted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.muted),
      );
}
