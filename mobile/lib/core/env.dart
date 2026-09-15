import 'package:flutter/foundation.dart' show kReleaseMode;

/// Compile-time environment.
class Env {
  const Env._();

  /// ───────────────────────────────────────────────────────────────────────
  /// ЕДИНСТВЕННОЕ МЕСТО, ГДЕ ЗАДАЁТСЯ АДРЕС СЕРВЕРА.
  ///
  /// Замените на свой домен перед сборкой релиза. Обязательно `https://` —
  /// внутри ходят пароли, JWT и все финансовые операции, а релизная сборка
  /// Android блокирует незашифрованный трафик (`usesCleartextTraffic=false`),
  /// так что адрес на `http://` просто не заработает.
  ///
  /// Без завершающего слэша: `ApiClient` склеивает пути вида `/v1/auth/login`.
  /// ───────────────────────────────────────────────────────────────────────
  static const _productionBaseUrl = 'https://mymoney.palantiry.ru';

  /// Переопределение на время разработки:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
  ///
  /// В релизной сборке игнорируется, если ведёт на http: собрать «боевой»
  /// APK, случайно указывающий на локальную машину по открытому каналу, —
  /// ровно та ошибка, которую эта проверка должна сделать невозможной.
  static const _override = String.fromEnvironment('API_BASE_URL');

  /// Base URL of MyMoney backend REST API (см. ADR-0005).
  ///
  /// Пользователь адрес не выбирает и не видит: экран «Подключение к серверу»
  /// убран вместе с хранением адреса в SharedPreferences. Приложение —
  /// клиент одного конкретного сервера, и предлагать вводить URL значило бы
  /// показывать людям деталь хостинга, до которой им нет дела.
  static String get apiBaseUrl {
    if (_override.isEmpty) return _productionBaseUrl;
    if (kReleaseMode && !_override.startsWith('https://')) {
      return _productionBaseUrl;
    }
    return _override;
  }

  /// Sync interval when app is in foreground.
  static const syncIntervalSeconds = int.fromEnvironment(
    'SYNC_INTERVAL_SECONDS',
    defaultValue: 60,
  );
}
