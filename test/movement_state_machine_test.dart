import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/domain/services/movement_features.dart';

void main() {
  test('counts a complete movement once and ignores a partial movement', () {
    final machine = RepetitionStateMachine(minimumAngleChange: 15);
    for (final angle in [170.0, 150.0, 140.0, 170.0, 165.0, 145.0, 130.0]) {
      machine.add(angle);
    }
    expect(machine.count, 1);
    expect(machine.phase, RepetitionPhase.descending);
  });
}