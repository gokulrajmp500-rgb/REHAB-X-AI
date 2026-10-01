import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/models/exercise.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('ExerciseDetailsPage renders on narrow screens without right overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    for (final exercise in exerciseCatalog) {
      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseDetailsPage(exercise: exercise),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('AnalyzePage exercises and Today Plan render without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AnalyzePage()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Switch to Today's Plan tab
    await tester.tap(find.text("Today's Plan"));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

