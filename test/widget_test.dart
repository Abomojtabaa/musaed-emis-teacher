import 'package:flutter_test/flutter_test.dart';
import 'package:iraq_emis/main.dart';

void main() {
  testWidgets('EMIS teacher intro is displayed', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.text('مساعد EMIS'), findsOneWidget);
    expect(find.text('للمعلم'), findsOneWidget);
  });
}
