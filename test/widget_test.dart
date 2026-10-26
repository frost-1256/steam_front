import 'package:flutter_test/flutter_test.dart';

import 'package:steam_front/main.dart';

void main() {
  testWidgets('app boots to the library screen', (tester) async {
    await tester.pumpWidget(const SteamFrontApp());
    await tester.pump();
    expect(find.text('Steam Front'), findsOneWidget);
  });
}
