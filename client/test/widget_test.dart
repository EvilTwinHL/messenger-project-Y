import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_messenger_app/main.dart';
import 'package:my_messenger_app/login_screen.dart';

void main() {
  testWidgets('Messenger app smoke test', (WidgetTester tester) async {
    // 🔥 Ми передаємо LoginScreen як початковий екран для тесту
    await tester.pumpWidget(const MyApp(initialScreen: LoginScreen()));

    // Перевіряємо, чи з'явився текст "Вхід у чат" або кнопка входу
    expect(find.text('Вхід у чат'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('УВІЙТИ'), findsOneWidget);
  });
}
