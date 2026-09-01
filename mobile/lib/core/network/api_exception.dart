import 'package:dio/dio.dart';

/// Every failure the UI can render, in one type.
///
/// The backend already writes its `message` for humans, so screens can show it
/// verbatim; [fieldErrors] maps straight onto form fields.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    required this.code,
    this.statusCode,
    this.fieldErrors = const <String, String>{},
  });

  final String message;
  final String code;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetworkError => code == 'NETWORK_ERROR' || code == 'TIMEOUT';
  bool get isNotFound => statusCode == 404;

  /// A short line for an inline error state — never a stack trace.
  String get shortMessage => switch (code) {
        'NETWORK_ERROR' => 'No connection',
        'TIMEOUT' => 'That took too long',
        _ => message,
      };

  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'The server is taking too long to respond. Try again in a moment.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const ApiException(
          message: 'We could not reach the server. Check your connection and try again.',
          code: 'NETWORK_ERROR',
        );
      case DioExceptionType.cancel:
        return const ApiException(message: 'Request cancelled.', code: 'CANCELLED');
      case DioExceptionType.badCertificate:
        return const ApiException(
          message: 'The connection is not secure.',
          code: 'BAD_CERTIFICATE',
        );
      case DioExceptionType.badResponse:
        break;
      // Any future member of the enum is treated as an ordinary bad response.
      default:
        break;
    }

    final Response<dynamic>? response = error.response;
    final Object? data = response?.data;

    if (data is Map<String, dynamic>) {
      final Object? envelope = data['error'];
      if (envelope is Map<String, dynamic>) {
        final Object? details = envelope['details'];
        return ApiException(
          message: envelope['message'] as String? ?? 'Something went wrong.',
          code: envelope['code'] as String? ?? 'UNKNOWN',
          statusCode: response?.statusCode,
          fieldErrors: details is Map<String, dynamic>
              ? details.map((String key, Object? value) => MapEntry<String, String>(key, '$value'))
              : const <String, String>{},
        );
      }
    }

    return ApiException(
      message: 'Something went wrong. Please try again.',
      code: 'UNKNOWN',
      statusCode: response?.statusCode,
    );
  }
}
