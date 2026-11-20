import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

enum SessionStatus { loading, authenticated, anonymous, unavailable }

final sessionProvider = Provider<SessionController>((ref) {
  final session = SessionController(ref.watch(apiProvider));
  ref.onDispose(session.dispose);
  return session;
});

class SessionController extends ChangeNotifier {
  SessionController(this.api) {
    api.onExpired = expire;
  }
  final ApiClient api;
  AppUser? user;
  SessionStatus status = SessionStatus.loading;
  String? error;
  String? challenge;
  int revision = 0;

  void expire() {
    user = null;
    revision++;
    status = SessionStatus.anonymous;
    notifyListeners();
  }

  Future<void> restore() async {
    status = SessionStatus.loading;
    error = null;
    notifyListeners();
    try {
      await api.restoreCookies();
      if (!api.rememberMe) {
        status = SessionStatus.anonymous;
        return;
      }
      await api.refresh();
      user = AppUser.fromJson(object(await api.request('/api/users/me')));
      revision++;
      status = SessionStatus.authenticated;
    } on FormatException catch (failure) {
      await api.clearSession();
      error = failure.message;
      status = SessionStatus.anonymous;
    } on ApiFailure catch (failure) {
      error = failure.message;
      status = failure.status == 401 || failure.status == 403
          ? SessionStatus.anonymous
          : SessionStatus.unavailable;
    } finally {
      notifyListeners();
    }
  }

  Future<void> login(String email, String password, bool rememberMe) async {
    await api.clearSession();
    api.rememberMe = rememberMe;
    await _accept(
      object(
        await api.request(
          '/api/auth/login',
          method: 'POST',
          authenticated: false,
          body: {
            'email': email.trim(),
            'password': password,
            'rememberMe': rememberMe,
          },
        ),
      ),
    );
  }

  Future<void> completeFirstLogin(
    String email,
    String password,
    bool rememberMe,
  ) async {
    await _accept(
      object(
        await api.request(
          '/api/auth/first-login/change-password',
          method: 'POST',
          authenticated: false,
          body: {
            'email': email.trim(),
            'newPassword': password,
            'session': challenge,
            'rememberMe': rememberMe,
          },
        ),
      ),
    );
  }

  Future<void> _accept(Json data) async {
    if (data['status'] == 'PASSWORD_CHANGE_REQUIRED') {
      challenge = data['session'] as String?;
      notifyListeners();
      return;
    }
    final token = data['accessToken'];
    if (token is! String || token.isEmpty) {
      throw const ApiFailure('Missing access token.');
    }
    try {
      api.accessToken = token;
      user = AppUser.fromJson(
        object(data['user'] ?? await api.request('/api/users/me')),
      );
      challenge = null;
      status = SessionStatus.authenticated;
      revision++;
      notifyListeners();
    } on FormatException {
      await api.clearSession();
      rethrow;
    }
  }

  Future<void> googleLogin() async {
    final redirect = Uri.tryParse(AppConfig.oauthRedirect);
    if (AppConfig.cognitoDomain.isEmpty ||
        AppConfig.cognitoClientId.isEmpty ||
        redirect == null ||
        redirect.scheme != 'odms') {
      throw const ApiFailure(
        'Google sign-in needs COGNITO_DOMAIN, COGNITO_CLIENT_ID and an allowed odms:// callback.',
      );
    }
    final state = base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    final domain = Uri.parse(AppConfig.cognitoDomain);
    final authorization = domain.replace(
      path: '/oauth2/authorize',
      queryParameters: {
        'identity_provider': 'Google',
        'response_type': 'code',
        'client_id': AppConfig.cognitoClientId,
        'redirect_uri': redirect.toString(),
        'scope': 'openid email profile',
        'state': state,
      },
    );
    final result = Uri.parse(
      await FlutterWebAuth2.authenticate(
        url: authorization.toString(),
        callbackUrlScheme: 'odms',
      ),
    );
    if (result.scheme != redirect.scheme ||
        result.host != redirect.host ||
        result.path != redirect.path ||
        result.queryParameters['state'] != state) {
      throw const ApiFailure('Invalid sign-in callback.');
    }
    final code = result.queryParameters['code'];
    if (code == null) {
      throw const ApiFailure('Google sign-in was not completed.');
    }
    await api.clearSession();
    api.rememberMe = true;
    await _accept(
      object(
        await api.request(
          '/api/auth/social/sync',
          method: 'POST',
          authenticated: false,
          body: {
            'code': code,
            'redirectUri': redirect.toString(),
            'intent': 'LOGIN_OR_REGISTER',
            'provider': 'GOOGLE',
            'rememberMe': true,
          },
        ),
      ),
    );
  }

  Future<void> logout() async {
    try {
      await api.request('/api/auth/logout', method: 'POST', retry: false);
    } finally {
      await api.clearSession();
      expire();
    }
  }
}
