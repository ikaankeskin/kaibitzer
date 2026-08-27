import 'package:flutter_test/flutter_test.dart';
import 'package:kaibitzer/app.dart';

void main() {
  testWidgets('home screen shows Kaibitzer and setup', (tester) async {
    await tester.pumpWidget(const KaibitzerApp());
    expect(find.text('KAIBITZER'), findsOneWidget);
    expect(find.text('Customize board & rules'), findsOneWidget);
    expect(find.text('9×9 vs computer'), findsOneWidget);

    await tester.tap(find.text('Customize board & rules'));
    await tester.pumpAndSettle();
    expect(find.text('New game'), findsOneWidget);
    expect(find.text('Japanese'), findsOneWidget);
    expect(find.text('Start game'), findsOneWidget);
  });
}
