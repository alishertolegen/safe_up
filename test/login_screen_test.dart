import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:diplomka/login.dart';

void main() {
  Widget createWidget() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
    );
  }

  testWidgets('Экран успешно отображается', (tester) async {
    await tester.pumpWidget(createWidget());

    expect(find.text('SafeUp'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('Пустой email показывает ошибку', (tester) async {
    await tester.pumpWidget(createWidget());

    await tester.tap(find.text('Войти'));
    await tester.pump();

    expect(find.text('Введите email'), findsOneWidget);
  });

  testWidgets('Некорректный email показывает ошибку', (tester) async {
    await tester.pumpWidget(createWidget());

    await tester.enterText(
        find.byType(TextField).first, 'invalid-email');
    await tester.enterText(
        find.byType(TextField).last, '12345678');

    await tester.tap(find.text('Войти'));
    await tester.pump();

    expect(find.text('Некорректный email'), findsOneWidget);
  });

  testWidgets('Короткий пароль показывает ошибку', (tester) async {
    await tester.pumpWidget(createWidget());

    await tester.enterText(
        find.byType(TextField).first, 'test@mail.com');
    await tester.enterText(
        find.byType(TextField).last, '123');

    await tester.tap(find.text('Войти'));
    await tester.pump();

    expect(
      find.text('Пароль должен содержать минимум 8 символов'),
      findsOneWidget,
    );
  });

  testWidgets('Переключение видимости пароля работает', (tester) async {
    await tester.pumpWidget(createWidget());

    final icon = find.byIcon(Icons.visibility_off_outlined);
    expect(icon, findsOneWidget);

    await tester.tap(icon);
    await tester.pump();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });
}
