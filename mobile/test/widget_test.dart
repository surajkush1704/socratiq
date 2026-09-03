import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';

void main() {
  testWidgets('SocratiqApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SocratiqApp());
    expect(find.byType(SocratiqApp), findsOneWidget);
  });
}
