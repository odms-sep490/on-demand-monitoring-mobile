import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odms_mobile/core/api_client.dart';
import 'package:odms_mobile/core/models.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions) handler;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(
  Object? data, {
  int status = 200,
  Map<String, List<String>>? headers,
}) => ResponseBody.fromString(
  jsonEncode({
    'success': status < 400,
    'data': data,
    if (status >= 400) 'message': 'Rejected',
  }),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
    ...?headers,
  },
);

void main() {
  test('unsupported roles cannot enter the mobile app', () {
    expect(() => parseRole('ADMIN'), throwsFormatException);
    expect(parseRole('STAFF'), AppRole.staff);
  });
  test('unwraps API envelopes and preserves validation errors', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
    dio.httpClientAdapter = FakeAdapter(
      (options) async => options.path.endsWith('/bad')
          ? ResponseBody.fromString(
              '{"success":false,"message":"Invalid","errors":{"name":"Required"}}',
              422,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            )
          : response({'id': 'one'}),
    );
    final api = ApiClient(
      'https://api.example',
      MemorySecrets(),
      transport: dio,
    );
    expect(await api.request('/api/good'), {'id': 'one'});
    await expectLater(
      api.request('/api/bad'),
      throwsA(
        isA<ApiFailure>()
            .having((e) => e.status, 'status', 422)
            .having((e) => object(e.errors)['name'], 'field error', 'Required'),
      ),
    );
  });
  test(
    'refresh sends CSRF and cookie, then retries with new bearer token',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
      final secrets = MemorySecrets();
      var refreshCount = 0;
      dio.httpClientAdapter = FakeAdapter((options) async {
        switch (options.path) {
          case '/api/auth/login':
            return response(
              {},
              headers: {
                'set-cookie': [
                  'OMSS_REFRESH_TOKEN=refresh::user; Path=/; HttpOnly; Secure; Max-Age=1000',
                ],
              },
            );
          case '/api/auth/csrf':
            return response(
              'csrf-token',
              headers: {
                'set-cookie': ['XSRF-TOKEN=csrf-cookie; Path=/; Secure'],
              },
            );
          case '/api/auth/refresh':
            refreshCount++;
            expect(options.headers['X-XSRF-TOKEN'], 'csrf-token');
            expect(
              options.headers['Cookie'],
              contains('OMSS_REFRESH_TOKEN=refresh::user'),
            );
            return response({'accessToken': 'fresh'});
          default:
            return options.headers['Authorization'] == 'Bearer fresh'
                ? response({'ok': true})
                : response(null, status: 401);
        }
      });
      final api = ApiClient('https://api.example', secrets, transport: dio)
        ..rememberMe = true;
      await api.request(
        '/api/auth/login',
        method: 'POST',
        authenticated: false,
      );
      api.accessToken = 'expired';
      expect(await api.request('/api/orders/mine'), {'ok': true});
      expect(refreshCount, 1);
      expect(secrets.values.values.single, contains('OMSS_REFRESH_TOKEN'));
      await api.clearSession();
      expect(secrets.values, isEmpty);
      expect(api.accessToken, isNull);
    },
  );
  test(
    'a network outage during refresh does not delete the saved session',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
      dio.httpClientAdapter = FakeAdapter(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      final secrets = MemorySecrets()..values['keep'] = 'saved';
      final api = ApiClient('https://api.example', secrets, transport: dio);
      await expectLater(api.refresh(), throwsA(isA<ApiFailure>()));
      expect(secrets.values['keep'], 'saved');
    },
  );
  test('concurrent expired requests share one refresh operation', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
    var refreshes = 0;
    dio.httpClientAdapter = FakeAdapter((options) async {
      if (options.path == '/api/auth/csrf') return response('csrf');
      if (options.path == '/api/auth/refresh') {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return response({'accessToken': 'new'});
      }
      return options.headers['Authorization'] == 'Bearer new'
          ? response({'ok': true})
          : response(null, status: 401);
    });
    final api = ApiClient(
      'https://api.example',
      MemorySecrets(),
      transport: dio,
    )..accessToken = 'old';
    final result = await Future.wait([
      api.request('/api/one'),
      api.request('/api/two'),
    ]);
    expect(result.length, 2);
    expect(refreshes, 1);
  });
  test(
    'logout rejects stale responses before they can restore cookies',
    () async {
      final reply = Completer<ResponseBody>();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
      dio.httpClientAdapter = FakeAdapter((_) => reply.future);
      final secrets = MemorySecrets();
      final api = ApiClient('https://api.example', secrets, transport: dio)
        ..rememberMe = true;
      final pending = api.request('/api/orders/mine');
      await api.clearSession();
      reply.complete(
        response(
          {},
          headers: {
            'set-cookie': ['OMSS_REFRESH_TOKEN=stale::user; Path=/; Secure'],
          },
        ),
      );
      await expectLater(
        pending,
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            'Session changed.',
          ),
        ),
      );
      expect(secrets.values, isEmpty);
      expect(api.accessToken, isNull);
    },
  );
}
