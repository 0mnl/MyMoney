import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../env.dart';

/// Shared Dio client for MyMoney REST API.
///
/// JWT-interceptor and refresh-flow will be attached in a later step once
/// auth screens exist. The client is intentionally minimal for the skeleton.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  return dio;
});
