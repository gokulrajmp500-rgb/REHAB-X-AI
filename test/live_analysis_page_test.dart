import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/models/exercise.dart';
import 'package:flutter_application_1/presentation/pages/live_analysis_page.dart';

void main() {
  testWidgets('LiveAnalysisPage renders clean viewport and floating athlete HUD elements', (tester) async {
    final exercise = exerciseCatalog.first;

    await tester.pumpWidget(
      MaterialApp(
        home: LiveAnalysisPage(exercise: exercise),
      ),
    );

    // Initial loading or initialization frame
    expect(find.byType(LiveAnalysisPage), findsOneWidget);
    expect(find.text('SQUAT'), findsAtLeastNWidgets(1));
    expect(find.text('REPS'), findsAtLeastNWidgets(1));
    expect(find.text('PHASE'), findsAtLeastNWidgets(1));
    expect(find.text('POSE'), findsAtLeastNWidgets(1));
    expect(find.text('VOICE FEEDBACK'), findsOneWidget);
    expect(find.byTooltip('Speech language'), findsOneWidget);
    expect(find.text('START ANALYSIS'), findsOneWidget);

    // Toggle detailed telemetry drawer
    expect(find.text('ALL DATA'), findsOneWidget);
    expect(find.text('KINEMATICS'), findsOneWidget);
    expect(find.text('ENERGY & HEAT'), findsOneWidget);
    expect(find.text('SYMMETRY'), findsOneWidget);

    // Tap KINEMATICS category
    await tester.tap(find.text('KINEMATICS'));
    await tester.pump();
    expect(find.text('JOINT ANGLE'), findsOneWidget);
    expect(find.text('VELOCITY'), findsOneWidget);

    // Tap ENERGY & HEAT category
    await tester.tap(find.text('ENERGY & HEAT'));
    await tester.pump();
    expect(find.text('ENERGY OUTPUT'), findsOneWidget);
    expect(find.text('HEAT INDEX'), findsOneWidget);

    // Toggle silhouette alignment guide
    final silhouetteToggle = find.byTooltip('Toggle Silhouette Guide');
    expect(silhouetteToggle, findsOneWidget);
    await tester.tap(silhouetteToggle);
    await tester.pump();

    // Toggle diagnostics / debug mode
    final debugToggle = find.byTooltip('Technical Diagnostics & Debug Mode');
    expect(debugToggle, findsOneWidget);
    await tester.tap(debugToggle);
    await tester.pump();
  });

  testWidgets('LiveAnalysisPage renders on narrow screen (320px) without overflow errors', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    for (final exercise in exerciseCatalog) {
      await tester.pumpWidget(
        MaterialApp(
          home: LiveAnalysisPage(exercise: exercise),
        ),
      );
      await tester.pump();
      final err = tester.takeException();
      if (err != null) {
        debugPrint('FAILED FOR: ${exercise.name} -> $err');
      }
      expect(err, isNull);
    }
  });
}

