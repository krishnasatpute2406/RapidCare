import 'package:flutter_test/flutter_test.dart';

import 'package:rapidcare_k/main.dart';

void main() {
  testWidgets('RapidCare app starts on its branded splash screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RapidCareApp());

    expect(find.text('RapidCare'), findsOneWidget);
    expect(find.byType(RapidCareApp), findsOneWidget);
  });
}
