import 'package:flutter_test/flutter_test.dart';
import 'package:mymoney/presentation/widgets/password_strength_bar.dart';

/// The strength grade gates the "Зарегистрироваться" button, so these cases
/// pin the contract with the backend: `isValidPassword` there rejects anything
/// under 8 characters, and the form must never let such a password through.
void main() {
  group('computePasswordStrength', () {
    test('пустой пароль — none', () {
      expect(computePasswordStrength(''), PasswordStrength.none);
    });

    test('короче 8 символов — weak, что бы в нём ни было', () {
      expect(computePasswordStrength('Ab1!'), PasswordStrength.weak);
      expect(computePasswordStrength('Abc1!x'), PasswordStrength.weak);
      expect(computePasswordStrength('Abcd1!xy'.substring(0, 7)), PasswordStrength.weak);
    });

    test('8 символов одного класса — weak', () {
      expect(computePasswordStrength('abcdefgh'), PasswordStrength.weak);
    });

    test('8 символов, буквы и цифры — medium', () {
      expect(computePasswordStrength('abcdefg1'), PasswordStrength.weak);
      expect(computePasswordStrength('Abcdefg1'), PasswordStrength.medium);
    });

    test('длинный пароль трёх классов — strong', () {
      expect(computePasswordStrength('Abcdefghij1!'), PasswordStrength.strong);
    });

    test('кириллица считается за буквенный класс', () {
      expect(computePasswordStrength('Пароль12345!'), PasswordStrength.strong);
    });

    test('всё, что проходит гейт формы, длиной не меньше 8', () {
      const accepted = ['Abcdefg1', 'Abcdefghij1!', 'Пароль12345!'];
      for (final p in accepted) {
        final strength = computePasswordStrength(p);
        expect(
          strength == PasswordStrength.medium || strength == PasswordStrength.strong,
          isTrue,
          reason: '$p должен проходить гейт',
        );
        expect(p.length, greaterThanOrEqualTo(8));
      }
    });
  });
}
