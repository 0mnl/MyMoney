import 'package:dio/dio.dart';

import '../../data/remote/api/auth_api.dart';

/// Turns a thrown auth failure into copy the onboarding screens can show.
///
/// Backend error codes come from `DomainErrors.kt` / `AuthRoutes.kt`; anything
/// unrecognised falls back to a generic message rather than leaking a stack
/// trace into the UI (which is what the old LoginScreen did with `e.toString()`).
String authErrorMessage(Object error) {
  if (error is AuthApiException) {
    switch (error.code) {
      case 'EMAIL_TAKEN':
        return 'Этот адрес уже зарегистрирован. Войдите в аккаунт.';
      case 'EMAIL_NOT_ALLOWED':
        return 'Регистрация на этом сервере пока по приглашениям. '
            'Попросите добавить ваш адрес.';
      case 'VALIDATION_FAILED':
        return error.details['field'] == 'password'
            ? 'Пароль должен быть не короче 8 символов.'
            : 'Проверьте адрес электронной почты.';
      case 'INVALID_CODE':
        final left = error.details['attemptsLeft'];
        return left == null
            ? 'Неверный код. Проверьте письмо и попробуйте ещё раз.'
            : 'Неверный код. Осталось попыток: $left.';
      case 'CODE_EXPIRED':
        return 'Срок действия кода истёк. Запросите новый.';
      case 'TOO_MANY_ATTEMPTS':
        return 'Слишком много попыток. Запросите новый код.';
      case 'RESEND_COOLDOWN':
        final wait = error.retryAfterSeconds;
        return wait == null
            ? 'Код уже отправлен. Подождите немного.'
            : 'Код уже отправлен. Повторить можно через $wait с.';
      case 'EMAIL_ALREADY_VERIFIED':
        return 'Почта уже подтверждена. Войдите в аккаунт.';
      case 'EMAIL_NOT_VERIFIED':
        return 'Подтвердите почту, чтобы войти.';
      case 'UNAUTHORIZED':
        return 'Неверный email или пароль.';
    }
    return error.message;
  }

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Сервер не отвечает. Попробуйте ещё раз.';
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        // Адрес сервера пользователь не задаёт и поменять не может —
        // отправлять его «в настройки» было бы советом в никуда.
        return 'Нет связи с сервером. Проверьте интернет и попробуйте ещё раз.';
      default:
        return 'Не удалось выполнить запрос. Попробуйте ещё раз.';
    }
  }

  return 'Что-то пошло не так. Попробуйте ещё раз.';
}
