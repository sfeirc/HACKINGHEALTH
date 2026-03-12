import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oralscan_ai/app/app.dart';

void main() {
  testWidgets('App loads with router', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: OralScanApp(),
      ),
    );
    expect(find.byType(OralScanApp), findsOneWidget);
  });
}
