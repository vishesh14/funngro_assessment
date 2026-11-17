import 'package:flutter_test/flutter_test.dart';

import 'package:funngro_assessment/main.dart';

void main() {
  testWidgets('Home screen lists both parts', (tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Part 1 - Earnings screen (rewritten)'), findsOneWidget);
    expect(find.text('Part 2 - Projects (pagination)'), findsOneWidget);
  });
}
