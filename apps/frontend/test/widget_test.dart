import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App loads onboarding screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartOutfitApp());

    expect(find.text('Stay '), findsNothing);
    expect(find.textContaining('Stylish'), findsOneWidget);
    expect(find.textContaining('Informed'), findsOneWidget);
    expect(find.text("Let’s go"), findsOneWidget);
  });
}