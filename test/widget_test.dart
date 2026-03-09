import 'package:flutter_test/flutter_test.dart';
import 'package:ecox/main.dart';

void main() {
  testWidgets('ClimapX app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ClimapXApp());
    // Verify the splash screen shows
    expect(find.text('ClimapX'), findsOneWidget);
  });
}
