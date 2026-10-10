// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('renders the REHAB-X AI dashboard without fake metrics', (
    tester,
  ) async {
    await tester.pumpWidget(const RehabXApp());

    expect(find.text('REHAB-X AI'), findsOneWidget);
    expect(find.text('Start movement\nanalysis'), findsOneWidget);
    expect(find.text('No sessions yet'), findsOneWidget);
    expect(find.text('--'), findsAtLeastNWidgets(2));
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue with email'), findsNothing);
  });

  testWidgets('analyze tab exposes the unavailable model state', (
    tester,
  ) async {
    await tester.pumpWidget(const RehabXApp());
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();

    expect(find.text('Pose analysis model is not configured.'), findsOneWidget);
    expect(find.text('Squat'), findsOneWidget);
  });
}
