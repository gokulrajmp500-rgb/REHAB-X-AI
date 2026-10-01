import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/models/exercise_analysis_config.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/services/technique_feedback_service.dart';

void main() {
  const service = TechniqueFeedbackService();

  test('flags a squat with insufficient movement range', () {
    final feedback = service.evaluate(
      metrics: const MovementMetrics(
        rangeOfMotion: 20,
        symmetry: null,
        consistency: 90,
        repetitions: 0,
        duration: Duration(seconds: 2),
        dataConfidence: .9,
        isMeasurementValid: true,
      ),
      config: ExerciseAnalysisConfig.squat,
    );

    expect(feedback.hasIssue, isTrue);
    expect(feedback.issue, contains('excursion'));
    expect(feedback.correction, contains('depth'));
  });

  test('flags a repetition that is too fast', () {
    final feedback = service.evaluate(
      metrics: const MovementMetrics(
        rangeOfMotion: 50,
        symmetry: null,
        consistency: 90,
        repetitions: 1,
        duration: Duration(seconds: 1),
        dataConfidence: .9,
        isMeasurementValid: true,
        repetitionDetails: [
          RepetitionDetail(
            repNumber: 1,
            durationSeconds: .2,
            rangeOfMotion: 50,
          ),
        ],
      ),
      config: ExerciseAnalysisConfig.squat,
    );

    expect(feedback.issue, contains('Rapid or uncontrolled'));
    expect(feedback.correction, contains('2 full seconds'));
    expect(feedback.nextAttemptCue, contains('1-2-3'));
  });

  test('accepts controlled measured form', () {
    final feedback = service.evaluate(
      metrics: const MovementMetrics(
        rangeOfMotion: 50,
        symmetry: null,
        consistency: 90,
        repetitions: 2,
        duration: Duration(seconds: 4),
        dataConfidence: .9,
        isMeasurementValid: true,
        repetitionDetails: [
          RepetitionDetail(repNumber: 1, durationSeconds: 1.5, rangeOfMotion: 50),
          RepetitionDetail(repNumber: 2, durationSeconds: 1.5, rangeOfMotion: 50),
        ],
      ),
      config: ExerciseAnalysisConfig.squat,
    );

    expect(feedback.hasIssue, isFalse);
    expect(feedback.issue, 'No major technique issue detected');
  });

  test('retrieves correct technique guide for squat, lunge, shoulder and balance', () {
    final squatGuide = CorrectTechniqueGuide.getGuideForExercise('squat');
    expect(squatGuide.title, 'Bodyweight Squat');
    expect(squatGuide.executionSteps, isNotEmpty);
    expect(squatGuide.commonMistakes, isNotEmpty);
    expect(squatGuide.cameraPlacement, contains('Side view'));

    final balanceGuide = CorrectTechniqueGuide.getGuideForExercise('balance');
    expect(balanceGuide.title, contains('Balance'));
    expect(balanceGuide.commonMistakes, isNotEmpty);

    final lungeGuide = CorrectTechniqueGuide.getGuideForExercise('lunge');
    expect(lungeGuide.title, contains('Lunge'));

    final shoulderGuide = CorrectTechniqueGuide.getGuideForExercise('shoulder_abduction');
    expect(shoulderGuide.title, contains('Shoulder'));
  });
}
