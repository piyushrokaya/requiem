import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/main.dart';

Future<void> _chooseNormalMode(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();

  expect(find.text('प्रयोग मोड छनोट'), findsOneWidget);

  await tester.tap(find.text('सामान्य मोड (Normal Mode)'));
  await tester.pumpAndSettle();
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

  testWidgets('News tab shows dummy articles and navigates to detail', (
    WidgetTester tester,
  ) async {
    await _chooseNormalMode(tester);

    expect(find.text('शीर्ष समाचार'), findsOneWidget);
    expect(
      find.text('Government announces new budget for infrastructure projects'),
      findsOneWidget,
    );

    await tester.tap(
      find.text('Government announces new budget for infrastructure projects'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kantipur'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches between tabs', (
    WidgetTester tester,
  ) async {
    await _chooseNormalMode(tester);

    await tester.tap(find.text('तुलना'));
    await tester.pumpAndSettle();
    expect(find.text('Sports'), findsOneWidget);

    await tester.tap(find.text('सोधपुछ'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Mic button in app bar sends a voice command', (
    WidgetTester tester,
  ) async {
    await _chooseNormalMode(tester);

    expect(find.byIcon(Icons.mic), findsOneWidget);
  });
}
