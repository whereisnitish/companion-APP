import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/profile.dart';

class AuthSession {
  const AuthSession({required this.tokens, required this.user});

  final AuthTokens tokens;
  final CurrentUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        tokens: AuthTokens(
          accessToken: json['accessToken'] as String,
          refreshToken: json['refreshToken'] as String,
        ),
        user: CurrentUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class AuthService {
  const AuthService(this._client);

  final ApiClient _client;

  Future<AuthSession> register({
    String? email,
    String? phone,
    required String password,
  }) async {
    final Map<String, dynamic> response = await _client.post(
      '/auth/register',
      skipAuth: true,
      body: <String, dynamic>{
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'password': password,
      },
    );
    return AuthSession.fromJson(response.dataObject);
  }

  Future<AuthSession> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final Map<String, dynamic> response = await _client.post(
      '/auth/login',
      skipAuth: true,
      body: <String, dynamic>{
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'password': password,
      },
    );
    return AuthSession.fromJson(response.dataObject);
  }

  /// Development OTP: the server returns the code so the flow is testable
  /// offline. In production the response carries only `{ sent: true }`.
  Future<String?> requestOtp(String phone) async {
    final Map<String, dynamic> response = await _client.post(
      '/auth/otp/request',
      skipAuth: true,
      body: <String, dynamic>{'phone': phone},
    );
    return response.dataObject['devCode'] as String?;
  }

  Future<AuthSession> verifyOtp(String phone, String code) async {
    final Map<String, dynamic> response = await _client.post(
      '/auth/otp/verify',
      skipAuth: true,
      body: <String, dynamic>{'phone': phone, 'code': code},
    );
    return AuthSession.fromJson(response.dataObject);
  }

  Future<void> logout(String refreshToken) async {
    await _client.post('/auth/logout', body: <String, dynamic>{'refreshToken': refreshToken});
  }
}
