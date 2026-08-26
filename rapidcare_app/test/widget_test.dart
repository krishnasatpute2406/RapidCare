import 'package:flutter_test/flutter_test.dart';
import 'package:rapidcare/main.dart';

void main() {
  testWidgets('Splash screen shows RapidCare text', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RapidCareApp());

    // Verify that the splash screen shows the text 'RAPIDCARE'
    expect(find.text('RAPIDCARE'), findsOneWidget);
  });
}
