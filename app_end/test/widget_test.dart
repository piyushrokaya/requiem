import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_app/core/state/accessibility_settings.dart';
import 'package:my_app/core/state/interaction_mode.dart';
import 'package:my_app/main.dart';

Widget _buildApp() {
  return MyApp(
    accessibilitySettings: AccessibilitySettings(),
    interactionMode: InteractionModeController(),
  );
}

Future<void> _skipDevServerSetup(WidgetTester tester) async {
  await tester.pumpWidget(_buildApp());
  await tester.pumpAndSettle();

  final skipFinder = find.textContaining('छोड्नुहोस्');
  expect(skipFinder, findsOneWidget);
  await tester.tap(skipFinder);
  await tester.pumpAndSettle();
}

Future<void> _chooseNormalMode(WidgetTester tester) async {
  await _skipDevServerSetup(tester);

  expect(find.text('कृपया आफ्नो प्रयोग मोड छनोट गर्नुहोस्'), findsOneWidget);

  await tester.tap(find.text('सामान्य मोड (Normal Mode)'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Mode selection offers voice and normal mode', (
    WidgetTester tester,
  ) async {
    await _skipDevServerSetup(tester);

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
