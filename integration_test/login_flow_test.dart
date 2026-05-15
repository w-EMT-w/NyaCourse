import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:gdut_class_schedule/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logs in and shows schedule', (tester) async {
    const username = String.fromEnvironment('GDUT_USERNAME');
    const password = String.fromEnvironment('GDUT_PASSWORD');
    if (username.isEmpty || password.isEmpty) {
      return;
    }

    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('登录').first);
    await tester.pumpAndSettle();

    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), username);
    await tester.enterText(fields.at(1), password);
    await tester.tap(find.text('登录并保存'));

    await tester.pumpAndSettle(const Duration(seconds: 45));

    expect(find.text('已同步教务课表'), findsOneWidget);
  });
}
