import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiUnauthorizedException extends ApiException {
  const ApiUnauthorizedException(super.message) : super(statusCode: 401);
}

/// Optional hook invoked whenever a request comes back 401, so callers
/// (e.g. AppProvider) can clear stored tokens and drop the session without
/// every repository call having to catch ApiUnauthorizedException itself.
typedef UnauthorizedHandler = void Function();

class ApiService {
  ApiService({Dio? dio, UnauthorizedHandler? onUnauthorized})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConstants.apiBaseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
              sendTimeout: const Duration(seconds: 12),
              headers: {'Content-Type': 'application/json'},
            ),
          ),
      _onUnauthorized = onUnauthorized {
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (log) => debugPrint('[ApiService] $log'),
        ),
      );
    }
  }

  final Dio _dio;
  final UnauthorizedHandler? _onUnauthorized;

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    return _request(() => _dio.get<dynamic>(path, options: _options(token)));
  }

  /// For endpoints that return a raw JSON array instead of an object.
  Future<List<dynamic>> getList(String path, {String? token}) async {
    try {
      final response = await _dio.get<dynamic>(path, options: _options(token));
      final data = response.data;
      if (data is List<dynamic>) return data;
      throw const FormatException('Expected a JSON array response.');
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    String? token,
  }) async {
    return _request(
      () => _dio.post<dynamic>(path, data: data, options: _options(token)),
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Object? data,
    String? token,
  }) async {
    return _request(
      () => _dio.put<dynamic>(path, data: data, options: _options(token)),
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? data,
    String? token,
  }) async {
    return _request(
      () => _dio.patch<dynamic>(path, data: data, options: _options(token)),
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Object? data,
    String? token,
  }) async {
    return _request(
      () => _dio.delete<dynamic>(path, data: data, options: _options(token)),
    );
  }

  Options _options(String? token) {
    return Options(
      headers: token == null ? null : {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      final response = await send();
      return _asMap(response.data);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  ApiException _toApiException(DioException error) {
    final statusCode = error.response?.statusCode;
    final backendMessage = _responseMessage(error.response?.data);
    final message = backendMessage ?? _networkMessage(error);
    if (statusCode == 401) {
      _onUnauthorized?.call();
      return ApiUnauthorizedException(message);
    }
    return ApiException(message, statusCode: statusCode);
  }

  String? _responseMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      final message = data['message'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (message is String && message.isNotEmpty) return message;
      if (detail is List && detail.isNotEmpty) return detail.first.toString();
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }

  String _networkMessage(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.unknown) {
      return 'Could not reach the City Runner backend at ${AppConstants.apiBaseUrl}.';
    }
    return error.message ?? 'Request failed.';
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Unexpected API response format.');
  }
}
