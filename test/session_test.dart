import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odms_mobile/core/api_client.dart';
import 'package:odms_mobile/features/auth/session.dart';

import 'api_client_test.dart' show FakeAdapter, MemorySecrets, response;

void main() {
  test('first login waits for password change before authenticating', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
    dio.httpClientAdapter = FakeAdapter(
      (options) async => options.path.endsWith('/login')
          ? response({
              'status': 'PASSWORD_CHANGE_REQUIRED',
              'session': 'challenge',
            })
          : response({
              'accessToken': 'token',
              'user': {
                'id': '1',
                'email': 'staff@example.com',
                'fullName': 'Staff',
                'role': 'STAFF',
              },
            }),
    );
    final session = SessionController(
      ApiClient('https://api.example', MemorySecrets(), transport: dio),
    );
    await session.login('staff@example.com', 'temporary', false);
    expect(session.challenge, 'challenge');
    expect(session.user, isNull);
    await session.completeFirstLogin(
      'staff@example.com',
      'newPassword1!',
      false,
    );
    expect(session.status, SessionStatus.authenticated);
    expect(session.challenge, isNull);
    session.dispose();
  });
  test('admin login clears session secrets and denies mobile access', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
    dio.httpClientAdapter = FakeAdapter(
      (options) async => response({
        'accessToken': 'token',
        'user': {
          'id': '1',
          'email': 'admin@example.com',
          'fullName': 'Admin',
          'role': 'ADMIN',
        },
      }),
    );
    final secrets = MemorySecrets();
    final api = ApiClient('https://api.example', secrets, transport: dio);
    final session = SessionController(api);
    await expectLater(
      session.login('admin@example.com', 'password', true),
      throwsFormatException,
    );
    expect(api.accessToken, isNull);
    expect(secrets.values, isEmpty);
    expect(session.user, isNull);
    session.dispose();
  });
}
