enum PlanStatus { notStarted, inProgress, completed, skipped, insufficientData }

class PersonalizedPlan {
  const PersonalizedPlan({required this.title, required this.focusArea, required this.stage, required this.exercises, required this.frequency, required this.progressionCriteria, required this.monitoringMetrics, required this.recoveryGuidance, required this.limitations, required this.generatedAt, this.athleteId = '', this.status = PlanStatus.notStarted});
  final String title;
  final String focusArea;
  final String stage;
  final List<PlanExercise> exercises;
  final String frequency;
  final String progressionCriteria;
  final List<String> monitoringMetrics;
  final String recoveryGuidance;
  final List<String> limitations;
  final DateTime generatedAt;
  final String athleteId;
  final PlanStatus status;

  Map<String, Object?> toJson() => {'title': title, 'focusArea': focusArea, 'stage': stage, 'exercises': exercises.map((exercise) => exercise.toJson()).toList(), 'frequency': frequency, 'progressionCriteria': progressionCriteria, 'monitoringMetrics': monitoringMetrics, 'recoveryGuidance': recoveryGuidance, 'limitations': limitations, 'generatedAt': generatedAt.toIso8601String(), 'athleteId': athleteId, 'status': status.name};

  factory PersonalizedPlan.fromJson(Map<String, Object?> json) => PersonalizedPlan(title: json['title'] as String? ?? 'Movement monitoring plan', focusArea: json['focusArea'] as String? ?? 'Movement quality', stage: json['stage'] as String? ?? 'Mobility', exercises: (json['exercises'] as List? ?? const []).map((item) => PlanExercise.fromJson(Map<String, Object?>.from(item as Map))).toList(), frequency: json['frequency'] as String? ?? '', progressionCriteria: json['progressionCriteria'] as String? ?? '', monitoringMetrics: List<String>.from(json['monitoringMetrics'] as List? ?? const []), recoveryGuidance: json['recoveryGuidance'] as String? ?? '', limitations: List<String>.from(json['limitations'] as List? ?? const []), generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0), athleteId: json['athleteId'] as String? ?? '', status: PlanStatus.values.where((value) => value.name == json['status']).firstOrNull ?? PlanStatus.notStarted);
}

class PlanExercise {
  const PlanExercise({required this.exerciseId, required this.name, required this.target, required this.sets, required this.repetitions, this.reason = ''});
  final String exerciseId;
  final String name;
  final String target;
  final int sets;
  final int repetitions;
  final String reason;
  Map<String, Object?> toJson() => {'exerciseId': exerciseId, 'name': name, 'target': target, 'sets': sets, 'repetitions': repetitions, 'reason': reason};
  factory PlanExercise.fromJson(Map<String, Object?> json) => PlanExercise(exerciseId: json['exerciseId'] as String? ?? '', name: json['name'] as String? ?? '', target: json['target'] as String? ?? '', sets: (json['sets'] as num?)?.toInt() ?? 0, repetitions: (json['repetitions'] as num?)?.toInt() ?? 0, reason: json['reason'] as String? ?? '');
}

class PlanDay {
  const PlanDay({required this.date, required this.exerciseIds, required this.status});
  final DateTime date;
  final List<String> exerciseIds;
  final PlanStatus status;
  Map<String, Object?> toJson() => {'date': date.toIso8601String(), 'exerciseIds': exerciseIds, 'status': status.name};
}

class PlanProgress {
  const PlanProgress({required this.planId, required this.completedExerciseIds, required this.skippedExerciseIds, required this.status, required this.updatedAt});
  final String planId;
  final List<String> completedExerciseIds;
  final List<String> skippedExerciseIds;
  final PlanStatus status;
  final DateTime updatedAt;
  Map<String, Object?> toJson() => {'planId': planId, 'completedExerciseIds': completedExerciseIds, 'skippedExerciseIds': skippedExerciseIds, 'status': status.name, 'updatedAt': updatedAt.toIso8601String()};
  factory PlanProgress.empty(String planId) => PlanProgress(planId: planId, completedExerciseIds: const [], skippedExerciseIds: const [], status: PlanStatus.notStarted, updatedAt: DateTime.now());
  factory PlanProgress.fromJson(Map<String, Object?> json) => PlanProgress(planId: json['planId'] as String? ?? '', completedExerciseIds: List<String>.from(json['completedExerciseIds'] as List? ?? const []), skippedExerciseIds: List<String>.from(json['skippedExerciseIds'] as List? ?? const []), status: PlanStatus.values.where((value) => value.name == json['status']).firstOrNull ?? PlanStatus.notStarted, updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0));
}