import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/models/exercise_analysis_config.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/services/live_voice_feedback_service.dart';

void main() {
  const formatter = LiveVoiceFeedbackService();
  const metrics = MovementMetrics(
    rangeOfMotion: 42.5,
    symmetry: 6.2,
    consistency: 87,
    stability: 91,
    duration: Duration(seconds: 4),
    repetitions: 3,
    velocity: 110.5,
    tempo: 2.1,
    dataConfidence: 0.94,
    validFrameRatio: 0.88,
    isMeasurementValid: true,
  );

  test('English squat speech includes exercise-specific measured details', () {
    final report = formatter.buildReport(
      config: ExerciseAnalysisConfig.squat,
      metrics: metrics,
      primaryAngle: 92,
      movementPhase: 'DESCENDING',
      coachingCue: 'Improve lighting and keep required joints visible.',
      language: VoiceFeedbackLanguage.english,
    );

    expect(report, contains('Bodyweight Squat exercise'));
    expect(report, contains('Knee angle 92 degrees'));
    expect(report, contains('maximum minus minimum measured angle'));
    expect(report, contains('Completed repetitions 3'));
    expect(report, contains('Tempo 2.1 seconds per repetition'));
    expect(report, contains('Movement consistency score 87 percent'));
    expect(report, contains('Left-to-right movement difference 6.2 percent'));
    expect(report, contains('Angular velocity 110.5 degrees per second'));
    expect(report, contains('Pose confidence 94 percent'));
    expect(report, contains('Movement phase DESCENDING'));
  });

  test('Tamil speech localizes the exercise, joint, and measured detail labels', () {
    final report = formatter.buildReport(
      config: ExerciseAnalysisConfig.squat,
      metrics: metrics,
      primaryAngle: 92,
      movementPhase: 'DESCENDING',
      coachingCue: 'Maintain controlled movement',
      language: VoiceFeedbackLanguage.tamil,
    );

    expect(report, contains('ஸ்குவாட்'));
    expect(report, contains('முழங்கால் கோணம்'));
    expect(report, contains('இயக்க வரம்பு'));
    expect(report, contains('மீள்செயல்கள் 3'));
    expect(report, contains('இயக்க நிலை கீழே இறங்குதல்'));
    expect(report, isNot(contains('Bodyweight Squat')));
  });

  test('balance speech reports stability and hold time instead of ROM/reps', () {
    final report = formatter.buildReport(
      config: ExerciseAnalysisConfig.singleLegBalance,
      metrics: metrics,
      primaryAngle: null,
      movementPhase: 'READY',
      coachingCue: '',
      language: VoiceFeedbackLanguage.english,
    );

    expect(report, contains('Balance stability 91 percent'));
    expect(report, contains('Balance time 4 seconds'));
    expect(report, isNot(contains('Range of motion')));
    expect(report, isNot(contains('Completed repetitions')));
  });

  test('incomplete measurements are not announced as measured values', () {
    const invalidMetrics = MovementMetrics(
      rangeOfMotion: 40,
      symmetry: 5,
      consistency: 80,
      duration: Duration(seconds: 2),
      repetitions: 2,
      dataConfidence: 0.4,
      validFrameRatio: 0.3,
      isMeasurementValid: false,
    );

    final report = formatter.buildReport(
      config: ExerciseAnalysisConfig.elbowFlexion,
      metrics: invalidMetrics,
      primaryAngle: null,
      movementPhase: 'READY',
      coachingCue: '',
      language: VoiceFeedbackLanguage.english,
    );

    expect(report, contains('Reliable measurements are not ready yet'));
    expect(report, isNot(contains('Range of motion 40')));
    expect(report, isNot(contains('Completed repetitions 2')));
  });
}