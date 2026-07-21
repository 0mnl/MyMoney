import '../dio_client.dart';
import '../dto/sync_dto.dart';

class SyncApi {
  SyncApi(this._client);
  final ApiClient _client;

  Future<SyncPullResponse> pull({DateTime? since}) async {
    final resp = await _client.dio.get<Map<String, dynamic>>(
      '/v1/sync/pull',
      queryParameters: since == null ? null : {'since': since.toUtc().toIso8601String()},
    );
    _requireOk(resp.statusCode, resp.data);
    return SyncPullResponse.fromJson(resp.data!);
  }

  Future<SyncPushResponse> push(SyncBundleDto bundle) async {
    final resp = await _client.dio.post<Map<String, dynamic>>(
      '/v1/sync/push',
      data: {'bundle': bundle.toJson()},
    );
    _requireOk(resp.statusCode, resp.data);
    return SyncPushResponse.fromJson(resp.data!);
  }

  void _requireOk(int? status, Map<String, dynamic>? data) {
    if (status == null || status >= 400) {
      final err = data?['error'] as Map<String, dynamic>?;
      throw SyncApiException(
        status: status ?? 0,
        code: err?['code']?.toString() ?? 'UNKNOWN',
        message: err?['message']?.toString() ?? 'Sync request failed',
      );
    }
  }
}

class SyncApiException implements Exception {
  SyncApiException({required this.status, required this.code, required this.message});
  final int status;
  final String code;
  final String message;
  @override
  String toString() => 'SyncApiException($status, $code): $message';
}
