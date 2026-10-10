import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/data/repositories/session_repository.dart';
import 'package:flutter_application_1/domain/models/pose_models.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'recovery and progress show empty states without placeholder data',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: RecoveryPage())),
      );
      await tester.pumpAndSettle();

      expect(find.text('No recorded sessions'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProgressPage())),
      );
      await tester.pumpAndSettle();
      expect(find.text('No verified movement sessions yet'), findsOneWidget);
      expect(find.text('24'), findsNothing);
    },
  );

  testWidgets('recovery refresh shows a newly saved session', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RecoveryPage())),
    );
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(find.text('No recorded sessions'), findsOneWidget);
    await LocalSessionRepository(preferences).create(
      SessionRecord(
        id: 'session-1',
        athleteId: 'athlete',
        exercise: 'Squat',
        exerciseId: 'squat',
        timestamp: DateTime.now(),
        metrics: const MovementMetrics(
          rangeOfMotion: 42,
          symmetry: null,
          consistency: 86,
          duration: Duration(seconds: 30),
          repetitions: 5,
          dataConfidence: .9,
          validFrameRatio: .9,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Refresh recovery'));
    await tester.pumpAndSettle();
    expect(find.text('Under 1 hour ago'), findsOneWidget);
    expect(find.text('86.0%'), findsOneWidget);
  });

  testWidgets('progress refresh shows a newly saved session', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProgressPage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('No verified movement sessions yet'), findsOneWidget);

    final preferences = await SharedPreferences.getInstance();
    await LocalSessionRepository(preferences).create(
      SessionRecord(
        id: 'session-1',
        athleteId: 'athlete',
        exercise: 'Squat',
        exerciseId: 'squat',
        timestamp: DateTime.now(),
        metrics: const MovementMetrics(
          rangeOfMotion: 42,
          symmetry: null,
          consistency: 86,
          duration: Duration(seconds: 30),
          repetitions: 5,
          dataConfidence: .9,
          validFrameRatio: .9,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Refresh progress'));
    await tester.pumpAndSettle();
    expect(find.text('No verified movement sessions yet'), findsNothing);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('both pages include sessions beyond the five most recent', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalSessionRepository(preferences);
    for (var index = 1; index <= 6; index++) {
      await repository.create(
        SessionRecord(
          id: 'session-$index',
          athleteId: 'athlete',
          exercise: 'Squat $index',
          exerciseId: 'squat',
          timestamp: DateTime.now().subtract(Duration(minutes: index)),
          metrics: const MovementMetrics(
            rangeOfMotion: 42,
            symmetry: null,
            consistency: 86,
            duration: Duration(seconds: 30),
            repetitions: 5,
            dataConfidence: .9,
            validFrameRatio: .9,
          ),
        ),
      );
    }

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RecoveryPage())),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Squat 6'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Squat 6'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProgressPage())),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Squat 6'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Squat 6'), findsOneWidget);
  });
}
