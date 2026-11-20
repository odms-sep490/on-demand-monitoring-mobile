import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class SecureSecretStore implements SecretStore {
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);
}

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.code, this.errors});
  final String message;
  final int? status;
  final String? code;
  final Object? errors;
  @override
  String toString() => message;
}

/// One backend origin, matching its HttpOnly refresh-cookie + CSRF contract.
/// Cookies are encrypted at rest. Access tokens remain in memory.
class ApiClient {
  ApiClient(String baseUrl, this.secrets, {Dio? transport})
    : dio =
          transport ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl.replaceFirst(RegExp(r'/$'), ''),
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 45),
            ),
          );
  final Dio dio;
  final SecretStore secrets;
  final Map<String, Cookie> _cookies = {};
  String? accessToken;
  Future<void>? _refreshing;
  void Function()? onExpired;
  bool rememberMe = false;
  int _generation = 0;
  String get _cookieKey =>
      'odms.cookies.${Uri.parse(dio.options.baseUrl).authority}';

  Future<void> restoreCookies() async {
    final encoded = await secrets.read(_cookieKey);
    if (encoded == null) return;
    try {
      for (final entry in jsonDecode(encoded) as List) {
        final cookie = Cookie.fromSetCookieValue(entry as String);
        if (cookie.expires == null || cookie.expires!.isAfter(DateTime.now())) {
          _cookies[cookie.name] = cookie;
        }
      }
      rememberMe = _cookies.isNotEmpty;
    } on FormatException {
      await secrets.write(_cookieKey, null);
    }
  }

  Future<void> clearSession() async {
    _generation++;
    accessToken = null;
    _cookies.clear();
    rememberMe = false;
    await secrets.write(_cookieKey, null);
  }

  Future<Object?> request(
    String path, {
    String method = 'GET',
    Object? body,
    Json? query,
    bool authenticated = true,
    bool retry = true,
    CancelToken? cancelToken,
  }) async {
    if (!path.startsWith('/api/')) {
      throw ArgumentError('Only ODMS API paths are allowed.');
    }
    final generation = _generation;
    try {
      final headers = <String, dynamic>{'Accept': 'application/json'};
      if (authenticated && accessToken != null) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
      final https = Uri.parse(dio.options.baseUrl).scheme == 'https';
      final cookies = _cookies.values.where(
        (c) =>
            (!c.secure || https) &&
            (c.expires == null || c.expires!.isAfter(DateTime.now())),
      );
      if (cookies.isNotEmpty) {
        headers['Cookie'] = cookies
            .map((c) => '${c.name}=${c.value}')
            .join('; ');
      }
      if (path == '/api/auth/refresh' || path == '/api/auth/logout') {
        final csrf = await request(
          '/api/auth/csrf',
          authenticated: false,
          retry: false,
        );
        headers['X-XSRF-TOKEN'] = csrf;
        headers['Cookie'] = _cookies.values
            .where((c) => !c.secure || https)
            .map((c) => '${c.name}=${c.value}')
            .join('; ');
      }
      final response = await dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(method: method, headers: headers),
      );
      if (generation != _generation) throw const ApiFailure('Session changed.');
      for (final value in response.headers['set-cookie'] ?? <String>[]) {
        final cookie = Cookie.fromSetCookieValue(value);
        if (cookie.maxAge != null && cookie.maxAge! > 0) {
          cookie.expires = DateTime.now().toUtc().add(
            Duration(seconds: cookie.maxAge!),
          );
        }
        if (cookie.maxAge == 0) {
          _cookies.remove(cookie.name);
        } else {
          _cookies[cookie.name] = cookie;
        }
      }
      if (rememberMe) {
        await secrets.write(
          _cookieKey,
          jsonEncode(_cookies.values.map((c) => c.toString()).toList()),
        );
      }
      final payload = object(response.data);
      if (payload['success'] == false) {
        throw ApiFailure(
          '${payload['message'] ?? 'Request failed'}',
          code: payload['code'] as String?,
          errors: payload['errors'],
        );
      }
      return payload['data'];
    } on DioException catch (error) {
      if (generation != _generation) throw const ApiFailure('Session changed.');
      if (error.response?.statusCode == 401 && authenticated && retry) {
        await refresh();
        return request(
          path,
          method: method,
          body: body,
          query: query,
          retry: false,
          cancelToken: cancelToken,
        );
      }
      final payload = object(error.response?.data);
      throw ApiFailure(
        '${payload['message'] ?? (error.response == null ? 'Cannot connect to ODMS. Check your connection and retry.' : 'Request failed (${error.response?.statusCode})')}',
        status: error.response?.statusCode,
        code: payload['code'] as String?,
        errors: payload['errors'],
      );
    }
  }

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<void> _refresh() async {
    try {
      final data = object(
        await request(
          '/api/auth/refresh',
          method: 'POST',
          authenticated: false,
          retry: false,
        ),
      );
      final token = data['accessToken'];
      if (token is! String || token.isEmpty) {
        throw const ApiFailure('Invalid authentication response.');
      }
      accessToken = token;
    } on ApiFailure catch (error) {
      if (error.status == 401 || error.status == 403) {
        await clearSession();
        onExpired?.call();
      }
      rethrow;
    }
  }
}
