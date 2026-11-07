import 'dart:typed_data';

import 'package:companion/core/network/api_client.dart';
import 'package:companion/core/storage/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what would go on the wire instead of sending it.
class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? last;
  List<int>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (requestStream != null) {
      lastBody = await requestStream.expand((Uint8List chunk) => chunk).toList();
    }
    return ResponseBody.fromString(
      '{"data":{}}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingAdapter adapter;
  late ApiClient client;

  String? contentTypeOf(RequestOptions options) {
    for (final MapEntry<String, dynamic> header in options.headers.entries) {
      if (header.key.toLowerCase() == Headers.contentTypeHeader) return '${header.value}';
    }
    return null;
  }

  setUp(() {
    adapter = _RecordingAdapter();
    client = ApiClient(
      tokenStorage: TokenStorage(),
      dio: Dio()..httpClientAdapter = adapter,
    );
  });

  test('raw bytes go out exactly as given, with the type they were given', () async {
    final Uint8List image = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 1, 2, 3]);

    await client.postBytes('/users/me/photo', image, contentType: 'image/jpeg');

    expect(contentTypeOf(adapter.last!), 'image/jpeg');
    expect(adapter.lastBody, image);
  });

  // The API answers a JSON content type on an empty body with a 400, which is
  // what used to break accepting an invitation.
  test('a POST without a body declares no content type', () async {
    await client.post('/invitations/abc/accept');
    expect(contentTypeOf(adapter.last!), isNull);
  });

  test('a DELETE without a body declares no content type', () async {
    await client.delete('/activities/abc');
    expect(contentTypeOf(adapter.last!), isNull);
  });

  test('a POST with a body is still sent as JSON', () async {
    await client.post('/invitations', body: <String, dynamic>{'recipientId': 'u1'});
    expect(contentTypeOf(adapter.last!), contains('application/json'));
  });
}
