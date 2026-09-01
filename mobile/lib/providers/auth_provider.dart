import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/realtime/socket_client.dart';
import '../core/storage/token_storage.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'core_providers.dart';

/// Where the app is in its lifecycle. The router reads exactly this.
enum AuthStage {
  /// Restoring a stored session — show the splash.
  loading,

  /// No session. Onboarding has not been seen yet.
  onboarding,

  /// No session, onboarding done.
  signedOut,

  /// Signed in but the profile has not been created.
  needsProfile,

  /// Fully set up.
  ready,
}

@immutable
class AuthState {
  const AuthState({required this.stage, this.user, this.errorMessage});

  final AuthStage stage;
  final CurrentUser? user;
  final String? errorMessage;

  static const AuthState loading = AuthState(stage: AuthStage.loading);

  bool get isAuthenticated => stage == AuthStage.ready || stage == AuthStage.needsProfile;

  AuthState copyWith({AuthStage? stage, CurrentUser? user, String? errorMessage}) => AuthState(
        stage: stage ?? this.stage,
        user: user ?? this.user,
        errorMessage: errorMessage,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(AuthState.loading) {
    _ref.read(apiClientProvider).onSessionExpired = _onSessionExpired;
    unawaited(restore());
  }

  final Ref _ref;

  static const String _onboardingSeenKey = 'companion.onboarding_seen';

  TokenStorage get _tokens => _ref.read(tokenStorageProvider);
  AuthService get _auth => _ref.read(authServiceProvider);
  ProfileService get _profiles => _ref.read(profileServiceProvider);
  SocketClient get _socket => _ref.read(socketClientProvider);
  SharedPreferences get _prefs => _ref.read(sharedPreferencesProvider);

  bool get _onboardingSeen => _prefs.getBool(_onboardingSeenKey) ?? false;

  /// Reads the keychain and, if a session is there, revalidates it against
  /// `/users/me` before letting anyone into the app.
  Future<void> restore() async {
    final AuthTokens? tokens = await _tokens.read();
    if (tokens == null) {
      state = AuthState(stage: _onboardingSeen ? AuthStage.signedOut : AuthStage.onboarding);
      return;
    }

    try {
      final CurrentUser user = await _profiles.fetchMe();
      _connectRealtime();
      state = AuthState(
        stage: user.isProfileComplete ? AuthStage.ready : AuthStage.needsProfile,
        user: user,
      );
    } catch (_) {
      await _tokens.clear();
      state = AuthState(stage: _onboardingSeen ? AuthStage.signedOut : AuthStage.onboarding);
    }
  }

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingSeenKey, true);
    if (state.stage == AuthStage.onboarding) {
      state = const AuthState(stage: AuthStage.signedOut);
    }
  }

  Future<void> register({String? email, String? phone, required String password}) async {
    final AuthSession session =
        await _auth.register(email: email, phone: phone, password: password);
    await _adopt(session);
  }

  Future<void> login({String? email, String? phone, required String password}) async {
    final AuthSession session = await _auth.login(email: email, phone: phone, password: password);
    await _adopt(session);
  }

  Future<void> verifyOtp(String phone, String code) async {
    final AuthSession session = await _auth.verifyOtp(phone, code);
    await _adopt(session);
  }

  Future<void> _adopt(AuthSession session) async {
    await _tokens.save(session.tokens);
    await _prefs.setBool(_onboardingSeenKey, true);
    _connectRealtime();
    state = AuthState(
      stage: session.user.isProfileComplete ? AuthStage.ready : AuthStage.needsProfile,
      user: session.user,
    );
  }

  /// Called after profile creation and after any profile edit.
  void setUser(CurrentUser user) {
    state = AuthState(
      stage: user.isProfileComplete ? AuthStage.ready : AuthStage.needsProfile,
      user: user,
    );
  }

  Future<void> refreshUser() async {
    try {
      setUser(await _profiles.fetchMe());
    } catch (_) {
      /* a failed refresh must never sign anyone out */
    }
  }

  Future<void> signOut() async {
    final String? refreshToken = await _tokens.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _auth.logout(refreshToken);
      } catch (_) {
        /* best effort — the local session goes either way */
      }
    }
    await _tokens.clear();
    _socket.disconnect();
    state = const AuthState(stage: AuthStage.signedOut);
  }

  void _connectRealtime() {
    final String? token = _tokens.cachedAccessToken;
    if (token != null) _socket.connect(token);
  }

  void _onSessionExpired() {
    _socket.disconnect();
    state = const AuthState(stage: AuthStage.signedOut);
  }
}

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((Ref ref) => AuthController(ref));

/// The signed-in user, or null. Most screens want this rather than the state.
final Provider<CurrentUser?> currentUserProvider =
    Provider<CurrentUser?>((Ref ref) => ref.watch(authControllerProvider).user);
