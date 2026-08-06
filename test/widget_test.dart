import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_color/main.dart';

void main() {
  testWidgets('Start screen shows play button', (WidgetTester tester) async {
    await tester.pumpWidget(const FantasyColorApp());
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}
