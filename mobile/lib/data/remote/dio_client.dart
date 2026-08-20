import 'dart:async';

import 'package:dio/dio.dart';

import 'auth_store.dart';

/// Wraps a Dio instance with two responsibilities:
///  - attach the current access token on every request
///  - transparently refresh once on 401, then retry the original request
///
/// The refresh path is serialised by a Completer so parallel 401s don't
/// spawn concurrent refresh calls (which would burn the rotation-single-use
/// contract in ADR-0005).
class ApiClient {
  ApiClient({required String baseUrl, required this.authStore})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
            validateStatus: (code) => code != null && code < 500,
          ),
        ) {
    dio.interceptors.add(_authInterceptor());
  }

  final Dio dio;
  final AuthStore authStore;

  Completer<bool>? _refreshLock;

  Interceptor _authInterceptor() => InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Auth endpoints must NOT carry a Bearer — refresh + login are open.
          if (!_isAuthEndpoint(options.path)) {
            final snap = await authStore.load();
            if (snap != null) {
              options.headers['Authorization'] = 'Bearer ${snap.accessToken}';
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) => handler.next(response),
        onError: (err, handler) async {
          final status = err.response?.statusCode;
          final path = err.requestOptions.path;
          if (status == 401 && !_isAuthEndpoint(path)) {
            final refreshed = await _attemptRefresh();
            if (refreshed) {
              try {
                final retry = await dio.fetch(err.requestOptions);
                return handler.resolve(retry);
              } catch (_) {
                // fall through — return the original error below
              }
            }
          }
          handler.next(err);
        },
      );

  bool _isAuthEndpoint(String path) =>
      path.startsWith('/v1/auth/login') ||
      path.startsWith('/v1/auth/register') ||
      path.startsWith('/v1/auth/verify-email') ||
      path.startsWith('/v1/auth/resend-code') ||
      path.startsWith('/v1/auth/refresh');

  Future<bool> _attemptRefresh() async {
    final inflight = _refreshLock;
    if (inflight != null) return inflight.future;
    final lock = Completer<bool>();
    _refreshLock = lock;
    try {
      final snap = await authStore.load();
      if (snap == null) {
        lock.complete(false);
        return false;
      }
      final resp = await dio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refreshToken': snap.refreshToken},
      );
      if (resp.statusCode == 200 && resp.data != null) {
        await authStore.updateTokens(
          accessToken: resp.data!['accessToken'] as String,
          refreshToken: resp.data!['refreshToken'] as String,
        );
        lock.complete(true);
        return true;
      }
      // Refresh failed — session is dead. Clear it so upper layers force login.
      await authStore.clear();
      lock.complete(false);
      return false;
    } catch (_) {
      await authStore.clear();
      lock.complete(false);
      return false;
    } finally {
      _refreshLock = null;
    }
  }
}
