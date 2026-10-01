import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/services/exercise_analyzers.dart';

void main() {
  test('squat analyzer refuses sequences without required measured landmarks', () {
    expect(() => SquatAnalyzer().analyze(const PoseSequence([])), throwsA(isA<InsufficientMovementDataException>()));
  });

  test('analyzers expose their required landmarks', () {
    expect(SquatAnalyzer().requiredLandmarks, containsAll(['hip', 'knee', 'ankle']));
    expect(ShoulderFlexionAnalyzer().requiredLandmarks, contains('shoulder'));
    expect(CalfRaiseAnalyzer().requiredLandmarks, contains('foot'));
    expect(CalfRaiseAnalyzer().config.requiredLandmarks, contains('foot'));
  });
}