import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/main.dart';

void main() {
  testWidgets('News tab shows dummy articles and navigates to detail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

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
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('तुलना'));
    await tester.pumpAndSettle();
    expect(find.text('Sports'), findsOneWidget);

    await tester.tap(find.text('सोधपुछ'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}
