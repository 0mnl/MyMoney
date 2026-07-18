/// Compile-time environment. Override with:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
class Env {
  const Env._();

  /// Base URL of MyMoney backend REST API (see ADR-0005).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Sync interval when app is in foreground.
  static const syncIntervalSeconds = int.fromEnvironment(
    'SYNC_INTERVAL_SECONDS',
    defaultValue: 60,
  );
}
