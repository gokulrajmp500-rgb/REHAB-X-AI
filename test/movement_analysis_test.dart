import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/domain/services/movement_analysis_service.dart';

void main() {
  test('calculates a joint angle from real landmark coordinates', () {
    const hip = PoseLandmark(name: 'hip', x: 0, y: 1);
    const knee = PoseLandmark(name: 'knee', x: 0, y: 0);
    const ankle = PoseLandmark(name: 'ankle', x: 1, y: 0);
    expect(angleBetween(hip, knee, ankle), closeTo(90, 0.001));
  });

  test('refuses insufficient pose data instead of manufacturing metrics', () {
    expect(() => MovementAnalysisService().analyze(const PoseSequence([])), throwsA(isA<InsufficientMovementDataException>()));
  });

  test('calculates range and duration from a measured sequence', () {
    final start = DateTime(2026, 1, 1);
    final frames = [
      PoseFrame(timestamp: start, landmarks: _landmarks(0)),
      PoseFrame(timestamp: start.add(const Duration(seconds: 1)), landmarks: _landmarks(30)),
      PoseFrame(timestamp: start.add(const Duration(seconds: 2)), landmarks: _landmarks(60)),
    ];
    final result = MovementAnalysisService().analyze(PoseSequence(frames));
    expect(result.rangeOfMotion, greaterThan(0));
    expect(result.duration, const Duration(seconds: 2));
  });
}

Map<String, PoseLandmark> _landmarks(double offset) => {
  'hip': PoseLandmark(name: 'hip', x: 0, y: 1),
  'knee': PoseLandmark(name: 'knee', x: 0, y: 0),
  'ankle': PoseLandmark(name: 'ankle', x: 1, y: offset / 60),
};