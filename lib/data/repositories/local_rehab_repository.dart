import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/athlete_profile.dart';
import '../models/app_settings.dart';
import '../models/competition.dart';
import '../../domain/models/personalized_plan.dart';

abstract interface class RehabRepository {
  Future<AthleteProfile?> loadProfile();
  Future<void> saveProfile(AthleteProfile profile);
  Future<void> removeProfile();
  Future<PersonalizedPlan?> loadPlan();
  Future<void> savePlan(PersonalizedPlan plan);
  Future<PlanProgress?> loadPlanProgress();
  Future<void> savePlanProgress(PlanProgress progress);
  Future<void> completePlanExercise(String planId, String exerciseId);
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<CompetitionEvent?> loadCompetition();
  Future<void> saveCompetition(CompetitionEvent event);
  Future<List<PreCompetitionChecklistItem>> loadCompetitionChecklist();
  Future<void> saveCompetitionChecklist(List<PreCompetitionChecklistItem> items);
  Future<Set<String>> loadFavorites();
  Future<void> toggleFavorite(String id);
  Future<void> clearAll();
}

class LocalRehabRepository implements RehabRepository {
  LocalRehabRepository(this.preferences);
  final SharedPreferences preferences;
  static const _profileKey = 'athlete_profile';
  static const _planKey = 'personalized_plan';
  static const _planProgressKey = 'plan_progress';
  static const _settingsKey = 'app_settings';
  static const _competitionKey = 'competition_event';
  static const _checklistKey = 'pre_competition_checklist';
  static const _favoritesKey = 'user_favorites';
  static const _schemaKey = 'local_data_schema_version';
  static const schemaVersion = 1;

  void _ensureSchema() {
    if ((preferences.getInt(_schemaKey) ?? 0) < schemaVersion) preferences.setInt(_schemaKey, schemaVersion);
  }

  @override
  Future<AthleteProfile?> loadProfile() async {
    _ensureSchema();
    final value = preferences.getString(_profileKey);
    if (value == null) return null;
    try {
      return AthleteProfile.fromJson(Map<String, Object?>.from(jsonDecode(value) as Map));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveProfile(AthleteProfile profile) async => preferences.setString(_profileKey, jsonEncode(profile.toJson()));

  @override
  Future<void> removeProfile() async => preferences.remove(_profileKey);

  @override
  Future<PersonalizedPlan?> loadPlan() async {
    _ensureSchema();
    final value = preferences.getString(_planKey);
    if (value == null) return null;
    try {
      return PersonalizedPlan.fromJson(Map<String, Object?>.from(jsonDecode(value) as Map));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> savePlan(PersonalizedPlan plan) async => preferences.setString(_planKey, jsonEncode(plan.toJson()));

  @override
  Future<PlanProgress?> loadPlanProgress() async {
    _ensureSchema();
    final value = preferences.getString(_planProgressKey);
    if (value == null) return null;
    try {
      return PlanProgress.fromJson(Map<String, Object?>.from(jsonDecode(value) as Map));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> savePlanProgress(PlanProgress progress) async => preferences.setString(_planProgressKey, jsonEncode(progress.toJson()));

  @override
  Future<void> completePlanExercise(String planId, String exerciseId) async {
    final plan = await loadPlan();
    final current = await loadPlanProgress() ?? PlanProgress.empty(planId);
    if (current.completedExerciseIds.contains(exerciseId)) return;
    final completed = {...current.completedExerciseIds, exerciseId}.toList();
    final planComplete = plan != null && plan.exercises.isNotEmpty && plan.exercises.every((exercise) => completed.contains(exercise.exerciseId));
    await savePlanProgress(PlanProgress(
      planId: planId,
      completedExerciseIds: completed,
      skippedExerciseIds: current.skippedExerciseIds.where((id) => id != exerciseId).toList(),
      status: planComplete ? PlanStatus.completed : PlanStatus.inProgress,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<AppSettings> loadSettings() async {
    _ensureSchema();
    final value = preferences.getString(_settingsKey);
    if (value == null) return const AppSettings();
    try {
      return AppSettings.fromJson(Map<String, Object?>.from(jsonDecode(value) as Map));
    } on Object {
      return const AppSettings();
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async => preferences.setString(_settingsKey, jsonEncode(settings.toJson()));

  @override
  Future<CompetitionEvent?> loadCompetition() async {
    _ensureSchema();
    final value = preferences.getString(_competitionKey);
    if (value == null) {
      return CompetitionEvent(
        name: 'State Track & Field Championship',
        sport: 'Athletics',
        event: '100m Sprint & Long Jump',
        date: DateTime(2026, 10, 15),
        startTime: '08:30 AM',
        reportingTime: '07:00 AM',
        venue: 'National Sports Complex Stadium',
        venueAddress: 'Gate 4, Arena Boulevard',
        travelTime: '35 mins (estimated)',
        equipment: 'Sprint spikes, Competition jersey, Foam roller, Electrolytes',
        organizer: 'National Athletics Federation',
        instructions: 'Report to holding tent 60 minutes prior to call time. Complete scheduled dynamic warm-up and mobility protocol.',
      );
    }
    try {
      return CompetitionEvent.fromJson(Map<String, Object?>.from(jsonDecode(value) as Map));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveCompetition(CompetitionEvent event) async =>
      preferences.setString(_competitionKey, jsonEncode(event.toJson()));

  @override
  Future<List<PreCompetitionChecklistItem>> loadCompetitionChecklist() async {
    _ensureSchema();
    final value = preferences.getString(_checklistKey);
    if (value == null) return defaultCompetitionChecklist;
    try {
      final list = jsonDecode(value) as List<dynamic>;
      return list.map((e) => PreCompetitionChecklistItem.fromJson(Map<String, Object?>.from(e as Map))).toList();
    } on Object {
      return defaultCompetitionChecklist;
    }
  }

  @override
  Future<void> saveCompetitionChecklist(List<PreCompetitionChecklistItem> items) async =>
      preferences.setString(_checklistKey, jsonEncode(items.map((e) => e.toJson()).toList()));

  @override
  Future<Set<String>> loadFavorites() async {
    _ensureSchema();
    final list = preferences.getStringList(_favoritesKey);
    return list?.toSet() ?? {'squat', 'lunge'};
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final favs = await loadFavorites();
    if (favs.contains(id)) {
      favs.remove(id);
    } else {
      favs.add(id);
    }
    await preferences.setStringList(_favoritesKey, favs.toList());
  }

  @override
  Future<void> clearAll() async => preferences.clear();
}