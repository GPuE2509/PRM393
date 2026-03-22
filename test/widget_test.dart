import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prm393/main.dart';

void main() {
  testWidgets('app root renders', (WidgetTester tester) async {
    await tester.pumpWidget(const Prm393App());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
