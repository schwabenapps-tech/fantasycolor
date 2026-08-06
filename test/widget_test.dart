import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fantasy_color/main.dart';
import 'package:fantasy_color/providers/favorites_store.dart';
import 'package:fantasy_color/screens/start_screen.dart';

void main() {
  testWidgets('Start screen shows fantasy play button', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FavoritesStore(),
        child: const FantasyColorApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(FantasyPlayButton), findsOneWidget);
  });
}
