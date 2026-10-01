import '../../data/models/athlete_profile.dart';
import '../../data/models/exercise.dart';
import '../models/personalized_plan.dart';
import '../models/pose_models.dart';
import 'trend_analysis_service.dart';

class RehabilitationPlanService {
  PersonalizedPlan generate({required AthleteProfile profile, required List<SessionRecord> sessions}) {
    final trend = TrendAnalysisService().analyze(sessions);
    final latest = trend.comparison.latest;
    final limitations = <String>[];
    final insufficientData = latest == null || latest.metrics.dataConfidence < 0.65 || latest.metrics.validFrameRatio < 0.7;
    String focus;
    if (insufficientData) {
      focus = 'Improve movement data quality';
      limitations.add('More reliable full-body visibility is needed before drawing movement conclusions.');
    } else if (latest.metrics.consistency < 70) {
      focus = 'Movement consistency';
    } else if (latest.metrics.symmetry != null && latest.metrics.symmetry! > 20) {
      focus = 'Symmetrical movement monitoring';
    } else if (trend.rom.direction == TrendDirection.reducing) {
      focus = 'Controlled range-of-motion monitoring';
    } else {
      focus = 'Maintain measured movement quality';
    }
    final squat = exerciseCatalog.firstWhere((exercise) => exercise.id == 'squat');
    final balance = exerciseCatalog.firstWhere((exercise) => exercise.id == 'balance');
    final exercises = insufficientData ? <PlanExercise>[] : [
      PlanExercise(exerciseId: squat.id, name: squat.name, target: focus, reason: 'Supports measured movement consistency monitoring.', sets: 2, repetitions: 5),
      PlanExercise(exerciseId: balance.id, name: balance.name, target: 'Observe stable posture and data quality', reason: 'Adds a low-complexity stability observation.', sets: 2, repetitions: 1),
    ];
    return PersonalizedPlan(title: 'Movement monitoring plan', focusArea: focus, stage: profile.recoveryStage, exercises: exercises, frequency: 'Review 2 to 3 sessions per week according to your established care plan.', progressionCriteria: 'Progress only after at least two consistent sessions with adequate data quality.', monitoringMetrics: const ['Range of motion', 'Symmetry when available', 'Movement consistency', 'Data confidence'], recoveryGuidance: 'Allow rest between sessions and stop if movement causes pain or discomfort. Seek professional guidance for concerns.', limitations: limitations, generatedAt: DateTime.now(), athleteId: profile.name, status: insufficientData ? PlanStatus.insufficientData : PlanStatus.notStarted);
  }
}