import 'dart:typed_data';

import 'package:companion/core/network/api_client.dart';
import 'package:companion/core/network/api_exception.dart';
import 'package:companion/core/storage/token_storage.dart';
import 'package:companion/models/profile.dart';
import 'package:companion/providers/auth_provider.dart';
import 'package:companion/providers/core_providers.dart';
import 'package:companion/services/profile_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const AuthTokens _session = AuthTokens(accessToken: 'access', refreshToken: 'refresh');

class _MemoryTokens extends TokenStorage {
  AuthTokens? tokens = _session;

  @override
  String? get cachedAccessToken => tokens?.accessToken;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<String?> readRefreshToken() async => tokens?.refreshToken;

  @override
  Future<void> save(AuthTokens value) async => tokens = value;

  @override
  Future<void> clear() async => tokens = null;
}

/// Everything answers 401, which forces a refresh; the refresh answers as scripted.
class _ExpiredTokenAdapter implements HttpClientAdapter {
  _ExpiredTokenAdapter(this.refresh);

  final Future<ResponseBody> Function(RequestOptions options) refresh;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.path.endsWith('/auth/refresh')) return refresh(options);
    return Future<ResponseBody>.value(_json(401));
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status) => ResponseBody.fromString(
      '{"error":{"code":"X","message":"x"}}',
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

class _FailingProfiles extends ProfileService {
  _FailingProfiles(this.failure) : super(ApiClient(tokenStorage: TokenStorage()));

  final ApiException failure;
  int attempts = 0;

  @override
  Future<CurrentUser> fetchMe() async {
    attempts += 1;
    throw failure;
  }
}

void main() {
  group('refreshing the session', () {
    Future<_MemoryTokens> attempt(Future<ResponseBody> Function(RequestOptions) refresh) async {
      final _MemoryTokens tokens = _MemoryTokens();
      final ApiClient client = ApiClient(
        tokenStorage: tokens,
        dio: Dio()..httpClientAdapter = _ExpiredTokenAdapter(refresh),
      );
      await expectLater(client.get('/users/me'), throwsA(isA<ApiException>()));
      return tokens;
    }

    test('keeps the session when the server cannot be reached', () async {
      final _MemoryTokens tokens = await attempt(
        (RequestOptions options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
      expect(tokens.tokens, isNotNull);
    });

    test('keeps the session when the server is failing', () async {
      expect((await attempt((_) async => _json(503))).tokens, isNotNull);
    });

    test('keeps the session when rate limited', () async {
      expect((await attempt((_) async => _json(429))).tokens, isNotNull);
    });

    test('ends the session when the server rejects the refresh token', () async {
      expect((await attempt((_) async => _json(401))).tokens, isNull);
    });
  });

  group('restoring the session at launch', () {
    Future<(_MemoryTokens, _FailingProfiles, AuthStage)> launch(ApiException failure) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'companion.onboarding_seen': true});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      AuthController.restoreRetryDelay = Duration.zero;

      final _MemoryTokens tokens = _MemoryTokens();
      final _FailingProfiles profiles = _FailingProfiles(failure);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
          tokenStorageProvider.overrideWithValue(tokens),
          profileServiceProvider.overrideWithValue(profiles),
        ],
      );
      addTearDown(container.dispose);

      container.read(authControllerProvider);
      await pumpEventQueue(times: 100);
      return (tokens, profiles, container.read(authControllerProvider).stage);
    }

    test('retries and keeps the session while offline', () async {
      final (_MemoryTokens tokens, _FailingProfiles profiles, AuthStage stage) = await launch(
        const ApiException(message: 'offline', code: 'NETWORK_ERROR'),
      );
      expect(profiles.attempts, 3);
      expect(tokens.tokens, isNotNull);
      expect(stage, AuthStage.signedOut);
    });

    test('retries and keeps the session while the server is failing', () async {
      final (_MemoryTokens tokens, _FailingProfiles profiles, _) = await launch(
        const ApiException(message: 'down', code: 'X', statusCode: 503),
      );
      expect(profiles.attempts, 3);
      expect(tokens.tokens, isNotNull);
    });

    test('drops the session straight away when the account is gone', () async {
      final (_MemoryTokens tokens, _FailingProfiles profiles, AuthStage stage) = await launch(
        const ApiException(message: 'gone', code: 'NOT_FOUND', statusCode: 404),
      );
      expect(profiles.attempts, 1);
      expect(tokens.tokens, isNull);
      expect(stage, AuthStage.signedOut);
    });
  });
}
