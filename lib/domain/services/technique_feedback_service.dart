import '../models/exercise_analysis_config.dart';
import '../models/pose_models.dart';

class TechniqueFeedback {
  const TechniqueFeedback({
    required this.issue,
    required this.correction,
    this.whyItMatters = '',
    this.nextAttemptCue = '',
    this.severity = 'info',
  });

  final String issue;
  final String correction;
  final String whyItMatters;
  final String nextAttemptCue;
  final String severity; // 'info', 'warning', 'critical'

  bool get hasIssue => issue != 'No major technique issue detected';
}

class CorrectTechniqueGuide {
  const CorrectTechniqueGuide({
    required this.exerciseId,
    required this.title,
    required this.cameraPlacement,
    required this.startingPosture,
    required this.executionSteps,
    required this.commonMistakes,
    required this.breathingPattern,
    required this.targetJointAction,
  });

  final String exerciseId;
  final String title;
  final String cameraPlacement;
  final String startingPosture;
  final List<String> executionSteps;
  final List<({String mistake, String correction})> commonMistakes;
  final String breathingPattern;
  final String targetJointAction;

  static CorrectTechniqueGuide getGuideForExercise(String exerciseId) =>
      TechniqueFeedbackService.getGuideForExercise(exerciseId);
}

class TechniqueFeedbackService {
  const TechniqueFeedbackService();

  TechniqueFeedback evaluate({
    required MovementMetrics metrics,
    required ExerciseAnalysisConfig config,
  }) {
    if (!metrics.isMeasurementValid || metrics.dataConfidence < config.minimumConfidence) {
      return const TechniqueFeedback(
        issue: 'Measurement quality insufficient to reliably assess form.',
        whyItMatters: 'Camera noise or partial joint occlusion prevents accurate geometric tracking.',
        correction: 'Improve room lighting and ensure every required joint is unobstructed in the frame.',
        nextAttemptCue: 'Step back into clear view and repeat when tracking turns green.',
        severity: 'warning',
      );
    }

    if (config.exerciseId == 'balance' && (metrics.stability ?? 0) < 85) {
      return const TechniqueFeedback(
        issue: 'Excessive lateral pelvic sway and trunk tilting.',
        whyItMatters: 'Compensating with upper body sway indicates hip abductor (gluteus medius) fatigue.',
        correction: 'Engage your core, keep your pelvis level with the floor, and fix your gaze on an eye-level focal point.',
        nextAttemptCue: 'Hold a firm core and reset before lifting the leg again.',
        severity: 'warning',
      );
    }

    if (metrics.repetitions == 0 && metrics.rangeOfMotion < config.minimumRepAngleChange * 1.5) {
      return TechniqueFeedback(
        issue: '${config.displayName} excursion did not reach inflection threshold.',
        whyItMatters: 'Repetitions require moving through a full eccentric-concentric cycle to measure adaptation.',
        correction: 'Initiate the movement with controlled depth before returning to full extension.',
        nextAttemptCue: 'Lower steadily until you feel target joint engagement, then push back up.',
        severity: 'info',
      );
    }

    if (metrics.rangeOfMotion < config.minimumRepAngleChange * 1.5) {
      return TechniqueFeedback(
        issue: 'Shallow joint excursion / incomplete range of motion.',
        whyItMatters: 'Partial repetitions reduce muscular recruitment and limit mobility progression.',
        correction: 'Gradually increase movement depth within a comfortable, pain-free range.',
        nextAttemptCue: 'Deepen the bottom position by 2-3 inches on your next repetition.',
        severity: 'info',
      );
    }

    if (metrics.repetitionDetails.any((detail) => detail.durationSeconds < config.minimumRepDurationSec)) {
      return TechniqueFeedback(
        issue: 'Rapid or uncontrolled repetition tempo.',
        whyItMatters: 'Fast uncontrolled movements rely on momentum rather than active muscle control.',
        correction: 'Control the lowering phase for at least 2 full seconds before reversing direction.',
        nextAttemptCue: 'Count "1-2-3" on the way down, pause briefly, then drive up.',
        severity: 'warning',
      );
    }

    if (metrics.consistency < 70) {
      return const TechniqueFeedback(
        issue: 'Inconsistent depth and timing between repetitions.',
        whyItMatters: 'Variability in joint angle and tempo indicates premature neuromuscular fatigue.',
        correction: 'Pick a consistent reference depth and lock in a steady metronome rhythm.',
        nextAttemptCue: 'Perform fewer reps with strict, identical form rather than rushing.',
        severity: 'info',
      );
    }

    if (metrics.symmetry != null && metrics.symmetry! > 18) {
      return TechniqueFeedback(
        issue: 'Bilateral kinematic asymmetry measured between left and right limbs (${metrics.symmetry!.toStringAsFixed(1)}%).',
        whyItMatters: 'Significant asymmetry places unequal shear force on the dominant side joint.',
        correction: 'Distribute ground reaction force evenly through both feet or limbs.',
        nextAttemptCue: 'Focus on pushing equally through both heels on the ascent.',
        severity: 'warning',
      );
    }

    return const TechniqueFeedback(
      issue: 'No major technique issue detected',
      whyItMatters: 'Kinematic alignment, joint excursion, and tempo are meeting optimal criteria.',
      correction: 'Maintain current cadence, postural stability, and controlled breathing.',
      nextAttemptCue: 'Keep this exact form for your remaining repetitions.',
      severity: 'info',
    );
  }

  static CorrectTechniqueGuide getGuideForExercise(String exerciseId) {
    switch (exerciseId.toLowerCase()) {
      case 'squat':
        return const CorrectTechniqueGuide(
          exerciseId: 'squat',
          title: 'Bodyweight Squat',
          cameraPlacement: 'Side view at hip height, 2.5 meters away, full body from head to shoes visible.',
          startingPosture: 'Feet shoulder-width apart, toes turned outward 10-15°, chest proud, arms extended forward for counterbalance.',
          executionSteps: [
            '1. Preparation: Brace your abdominal wall and shift weight slightly onto your midfoot/heels.',
            '2. Descent: Push hips back and bend knees simultaneously, tracking knees in line with second toes.',
            '3. Bottom Position: Lower until thighs are parallel to the floor (approx 90° knee angle) while keeping torso upright.',
            '4. Ascent: Drive through the tripod of your feet, pushing floor away to return to tall standing posture.',
          ],
          commonMistakes: [
            (
              mistake: 'Knees caving inward (Valgus collapse)',
              correction: 'Actively push your knees outward against an imaginary band as you squat.',
            ),
            (
              mistake: 'Heels lifting off the ground',
              correction: 'Sit back into hips and keep weight anchored through heels and outer foot.',
            ),
            (
              mistake: 'Excessive forward torso lean',
              correction: 'Keep chest tall, look forward, and mobilize ankle dorsiflexion.',
            ),
          ],
          breathingPattern: 'Inhale on the descent to create intra-abdominal pressure; exhale forcefully through pursed lips on the ascent.',
          targetJointAction: 'Simultaneous hip flexion & knee flexion during eccentric phase; hip & knee extension during concentric phase.',
        );

      case 'lunge':
        return const CorrectTechniqueGuide(
          exerciseId: 'lunge',
          title: 'Forward / Reverse Lunge',
          cameraPlacement: 'Side view at waist height, 2.5 meters away, front and rear foot clearly visible.',
          startingPosture: 'Standing tall with feet hip-width apart, shoulders back, hands on hips or at chest.',
          executionSteps: [
            '1. Step: Take a controlled step forward or backward, keeping hips square.',
            '2. Descent: Lower your center of mass straight down until both knees create approx 90° angles.',
            '3. Bottom Position: Front knee tracks directly over ankle; rear knee hovers 1-2 inches above floor.',
            '4. Ascent: Drive through front heel to return cleanly to starting tall stance.',
          ],
          commonMistakes: [
            (
              mistake: 'Front knee pushing far past toes with heel elevated',
              correction: 'Take a longer stride and drop hips down rather than sliding forward.',
            ),
            (
              mistake: 'Torso swaying or tilting side to side',
              correction: 'Keep hips wide like standing on train tracks, not a tightrope.',
            ),
          ],
          breathingPattern: 'Inhale as you lower your body; exhale as you push back to standing.',
          targetJointAction: 'Unilateral knee flexion and hip extension with core anti-rotation stability.',
        );

      case 'shoulder_abduction':
      case 'shoulder_flexion':
        return const CorrectTechniqueGuide(
          exerciseId: 'shoulder_abduction',
          title: 'Scapular Shoulder Elevation',
          cameraPlacement: 'Front-facing camera, 2.0 meters away, full upper torso, shoulders, and raised arms in frame.',
          startingPosture: 'Standing upright with neutral spine, shoulders relaxed down from ears, arms at sides.',
          executionSteps: [
            '1. Initiation: Set your shoulder blades down and back.',
            '2. Elevation: Raise arms smoothly in the scapular plane (30° forward of coronal plane) up to shoulder/ear height.',
            '3. Peak: Hold top position for a split second with zero neck shrugging.',
            '4. Return: Lower arms slowly with eccentric control over 2-3 seconds.',
          ],
          commonMistakes: [
            (
              mistake: 'Shrugging shoulders up toward ears (Upper trap substitution)',
              correction: 'Keep distance between shoulders and earlobes; lead with elbows.',
            ),
            (
              mistake: 'Arching lower back to heave arms up',
              correction: 'Brace abdominal core and glutes to prevent lumbar extension.',
            ),
          ],
          breathingPattern: 'Inhale before raising; exhale smoothly during elevation; inhale during lowering.',
          targetJointAction: 'Glenohumeral abduction with coordinated scapulothoracic upward rotation.',
        );

      case 'balance':
      default:
        return const CorrectTechniqueGuide(
          exerciseId: 'balance',
          title: 'Single-Leg Balance Stability',
          cameraPlacement: 'Front-facing view, 2 meters away, entire body from head to floor in frame.',
          startingPosture: 'Standing tall on level ground with weight centered equally.',
          executionSteps: [
            '1. Shift weight onto stance leg, lightly engaging glute and core.',
            '2. Lift opposite foot off floor, bending knee to approx 45-90° without touching stance leg.',
            '3. Fix gaze on a stationary point 2-3 meters ahead at eye level.',
            '4. Maintain tall posture with minimal pelvis tipping for the target duration.',
          ],
          commonMistakes: [
            (
              mistake: 'Dropping the unsupported hip (Trendelenburg sign)',
              correction: 'Squeeze stance glute firmly to keep pelvic crests completely horizontal.',
            ),
            (
              mistake: 'Clawing toes or locking stance knee rigidly',
              correction: 'Keep micro-flexion in stance knee and distribute weight across whole foot.',
            ),
          ],
          breathingPattern: 'Continuous, slow diaphragmatic breathing throughout the hold.',
          targetJointAction: 'Isometric hip stabilization via gluteus medius and ankle proprioception.',
        );
    }
  }
}
