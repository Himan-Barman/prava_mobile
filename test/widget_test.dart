import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shell/app.dart';

void main() {
  testWidgets('Prava app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const PravaApp());
    expect(find.byType(PravaApp), findsOneWidget);
  });
}
