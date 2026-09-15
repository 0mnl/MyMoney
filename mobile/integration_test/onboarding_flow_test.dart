import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mymoney/main.dart' as app;

/// Walks the real app through the onboarding flow on a device/simulator and
/// captures each screen.
///
/// Run with a backend up (see HOWTO_RUN §2):
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/onboarding_flow_test.dart \
///     -d `device-id`
///
/// The confirmation step needs the 6-digit code from the backend log, so this
/// test stops at the OTP screen rather than pretending to guess it — see
/// AuthRoutesIntegrationTest for the server-side happy path.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('онбординг: приветствие → регистрация → подтверждение почты',
      (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // 1. Добро пожаловать, первый слайд.
    expect(find.text('Создать аккаунт'), findsOneWidget);
    await binding.takeScreenshot('01-welcome-slide-1');

    // 2. Второй слайд карусели.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-welcome-slide-2');

    // 3. Экран регистрации, пустая форма.
    await tester.tap(find.text('Создать аккаунт'));
    await tester.pumpAndSettle();
    expect(find.text('Создайте аккаунт'), findsOneWidget);
    await binding.takeScreenshot('03-create-account-empty');

    // 4. Ошибка валидации email — снимается по потере фокуса.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'not-an-email');
    await tester.pumpAndSettle();
    await tester.tap(fields.at(1));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04-create-account-email-error');

    // 5. Слабый пароль — красная шкала, кнопка заблокирована.
    //    Фокус ставим явным тапом: enterText сам по себе не перехватывает
    //    фокус у соседнего поля, и текст молча уходит в то, что было
    //    сфокусировано раньше. Проверяем результат каждого ввода, иначе
    //    промах остаётся незамеченным и скриншот врёт.
    await tester.tap(fields.at(0));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(0), 'demo@example.com');
    await tester.pumpAndSettle();
    expect(
      find.text('Проверьте адрес электронной почты'),
      findsNothing,
      reason: 'валидный email должен снять ошибку — иначе ввод ушёл не в то поле',
    );

    await tester.tap(fields.at(1));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(1), 'abc');
    await tester.pumpAndSettle();
    expect(find.text('Слабый пароль — добавьте цифры или заглавные буквы'), findsOneWidget);
    await binding.takeScreenshot('05-create-account-weak-password');

    // 6. Надёжный пароль — зелёная шкала, кнопка активна.
    await tester.enterText(fields.at(1), 'Demo12345!x');
    await tester.pumpAndSettle();
    expect(find.text('Надёжный пароль'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
      reason: 'валидный email + надёжный пароль должны разблокировать кнопку',
    );
    await binding.takeScreenshot('06-create-account-strong-password');

    // 7. Отправка. С поднятым бэкендом уводит на экран подтверждения,
    //    без него — показывает ошибку связи. Снимаем что получилось.
    await tester.tap(find.text('Зарегистрироваться'));
    await tester.pumpAndSettle(const Duration(seconds: 10));
    await binding.takeScreenshot('07-after-submit');
  });
}
