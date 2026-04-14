import 'package:flutter_test/flutter_test.dart';
import 'package:bogi_property/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BogiPropertyApp());
    expect(find.byType(BogiPropertyApp), findsOneWidget);
  });
}
