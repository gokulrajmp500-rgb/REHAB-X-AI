import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/services/movement_features.dart';

void main() {
  test('rejects low-confidence landmarks', () {
    const landmark = PoseLandmark(name: 'knee', x: 0, y: 0, confidence: 0.4);
    expect(landmark.isValid, isFalse);
  });

  test('calculates asymmetry and repetition count from input values', () {
    expect(calculateAsymmetry(90, 60), closeTo(40, 0.001));
    expect(countRepetitions([170, 120, 170, 115, 170]), 2);
  });

  test('serializes a pose frame without losing confidence', () {
    final frame = PoseFrame(timestamp: DateTime(2026), landmarks: const {'hip': PoseLandmark(name: 'hip', x: 0.2, y: 0.3, confidence: 0.9)});
    final restored = PoseFrame.fromJson(frame.toJson());
    expect(restored.landmarks['hip']?.confidence, 0.9);
  });
}