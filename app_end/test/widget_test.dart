import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/main.dart';

Future<void> _chooseNormalMode(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();

  expect(find.text('कृपया आफ्नो प्रयोग मोड छनोट गर्नुहोस्'), findsOneWidget);

  await tester.tap(find.text('सामान्य मोड (Normal Mode)'));
  await tester.pump();
}

void main() {
  testWidgets('Mode selection offers voice and normal mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('आवाज मोड (Voice Mode)'), findsOneWidget);
    expect(find.text('सामान्य मोड (Normal Mode)'), findsOneWidget);
  });

  testWidgets('Normal mode lands on the News tab shell', (
    WidgetTester tester,
  ) async {
    await _chooseNormalMode(tester);

    // News/Compare pages call out to the backend (via FutureBuilder), which
    // isn't available in a widget test — just verify the shell (app bar,
    // bottom nav) renders while that request is in flight.
    expect(find.text('समाचार'), findsWidgets);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
