import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/models/athlete_profile.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/services/rehabilitation_plan_service.dart';
import 'package:flutter_application_1/domain/models/personalized_plan.dart';
import 'package:flutter_application_1/data/repositories/local_rehab_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('low-confidence data prioritizes data quality over exercise conclusions', () {
    final plan = RehabilitationPlanService().generate(profile: const AthleteProfile(name: 'A'), sessions: [SessionRecord(id: '1', athleteId: 'a', exercise: 'Squat', exerciseId: 'squat', timestamp: DateTime(2026), metrics: const MovementMetrics(rangeOfMotion: 30, symmetry: null, consistency: 85, duration: Duration.zero, repetitions: 2, dataConfidence: .4, validFrameRatio: .3))]);
    expect(plan.focusArea, 'Improve movement data quality');
    expect(plan.limitations, isNotEmpty);
  });

  test('low consistency selects consistency monitoring and uses conservative progression', () {
    final plan = RehabilitationPlanService().generate(profile: const AthleteProfile(name: 'A', recoveryStage: 'Strength'), sessions: [SessionRecord(id: '1', athleteId: 'a', exercise: 'Squat', exerciseId: 'squat', timestamp: DateTime(2026), metrics: const MovementMetrics(rangeOfMotion: 30, symmetry: null, consistency: 55, duration: Duration.zero, repetitions: 2, dataConfidence: .9, validFrameRatio: .9))]);
    expect(plan.focusArea, 'Movement consistency');
    expect(plan.stage, 'Strength');
    expect(plan.progressionCriteria, contains('two consistent sessions'));
  });

  test('persists plan progress through the existing local repository', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalRehabRepository(await SharedPreferences.getInstance());
    final progress = PlanProgress(planId: 'plan', completedExerciseIds: const ['squat'], skippedExerciseIds: const [], status: PlanStatus.inProgress, updatedAt: DateTime(2026));
    await repository.savePlanProgress(progress);
    expect((await repository.loadPlanProgress())?.completedExerciseIds, ['squat']);
  });
}