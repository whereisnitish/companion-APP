import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Thin, typed wrapper over Dio.
///
/// Two responsibilities beyond plain HTTP:
///   1. attach the access token to every call;
///   2. when one 401s, refresh once and replay — transparently, and only once
///      even if ten requests fail at the same moment.
class ApiClient {
  ApiClient({required TokenStorage tokenStorage, Dio? dio})
      : _tokens = tokenStorage,
        _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: AppConfig.apiRoot,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      // We inspect status codes ourselves so the interceptor can refresh.
      validateStatus: (int? status) => status != null && status < 500,
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          // The API rejects a JSON content type on an empty body, and actions
          // such as accepting an invitation have nothing to send.
          if (options.data == null) options.contentType = null;

          final String? token = _tokens.cachedAccessToken;
          if (token != null && !options.extra.containsKey('skipAuth')) {
            options.headers['authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: false, responseBody: false, request: false, error: true),
      );
    }
  }

  final Dio _dio;
  final TokenStorage _tokens;

  /// Invoked when a refresh fails — the session is gone and the app must sign out.
  VoidCallback? onSessionExpired;

  /// Invoked with the new access token whenever the session is refreshed.
  void Function(String accessToken)? onTokenRefreshed;

  Future<void>? _refreshInFlight;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query, cancelToken: cancelToken));

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool skipAuth = false,
    CancelToken? cancelToken,
  }) =>
      _send(
        () => _dio.post<dynamic>(
          path,
          data: body,
          cancelToken: cancelToken,
          options: Options(extra: skipAuth ? <String, dynamic>{'skipAuth': true} : null),
        ),
      );

  /// Sends raw bytes as the request body, such as an image.
  Future<Map<String, dynamic>> postBytes(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) =>
      // Built inside the closure so a retry after a token refresh gets a fresh stream.
      _send(
        () => _dio.post<dynamic>(
          path,
          data: Stream<List<int>>.value(bytes),
          options: Options(
            contentType: contentType,
            headers: <String, dynamic>{Headers.contentLengthHeader: bytes.length},
          ),
        ),
      );

  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<dynamic>(path, data: body));

  /// Runs the request, refreshing the session once on a 401 before giving up.
  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request, {
    bool allowRetry = true,
  }) async {
    Response<dynamic> response;
    try {
      response = await request();
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }

    final int status = response.statusCode ?? 500;

    if (status == 401 && allowRetry) {
      final bool refreshed = await _refreshSession();
      if (refreshed) return _send(request, allowRetry: false);
    }

    if (status >= 400) {
      throw ApiException.fromDioException(
        DioException.badResponse(
          statusCode: status,
          requestOptions: response.requestOptions,
          response: response,
        ),
      );
    }

    final Object? data = response.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{'data': data};
  }

  /// Coalesces concurrent refreshes into a single network call.
  Future<bool> _refreshSession() {
    final Future<void>? inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight.then((_) => _tokens.cachedAccessToken != null);

    final Completer<void> completer = Completer<void>();
    _refreshInFlight = completer.future;

    return () async {
      try {
        final String? refreshToken = await _tokens.readRefreshToken();
        if (refreshToken == null) {
          onSessionExpired?.call();
          return false;
        }

        final Response<dynamic> response = await _dio.post<dynamic>(
          '/auth/refresh',
          data: <String, dynamic>{'refreshToken': refreshToken},
          options: Options(extra: const <String, dynamic>{'skipAuth': true}),
        );

        final Object? body = response.data;
        if (response.statusCode == 200 && body is Map<String, dynamic>) {
          final Map<String, dynamic> session = body['data'] as Map<String, dynamic>;
          await _tokens.save(
            AuthTokens(
              accessToken: session['accessToken'] as String,
              refreshToken: session['refreshToken'] as String,
            ),
          );
          onTokenRefreshed?.call(session['accessToken'] as String);
          return true;
        }

        // Only the server saying the session is over ends it. A busy or limited
        // server is temporary, and signing someone out would not help.
        if (response.statusCode == 401) {
          await _tokens.clear();
          onSessionExpired?.call();
        }
        return false;
      } catch (_) {
        // No answer at all: offline, or the server still waking. Keep the session.
        return false;
      } finally {
        completer.complete();
        _refreshInFlight = null;
      }
    }();
  }
}

/// Unwraps the `{ data, meta }` envelope every endpoint returns.
extension ApiEnvelope on Map<String, dynamic> {
  Map<String, dynamic> get dataObject => this['data'] as Map<String, dynamic>? ?? const {};

  List<Map<String, dynamic>> get dataList {
    final Object? data = this['data'];
    if (data is List) return data.whereType<Map<String, dynamic>>().toList(growable: false);
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> get meta => this['meta'] as Map<String, dynamic>? ?? const {};
}
