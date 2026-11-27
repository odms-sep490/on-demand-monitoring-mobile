import 'dart:io';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odms_mobile/core/api_client.dart';
import 'package:odms_mobile/core/mobile_policy.dart';
import 'package:odms_mobile/core/models.dart';
import 'package:odms_mobile/features/staff/media_upload.dart';

import 'api_client_test.dart' show FakeAdapter, MemorySecrets, response;

void main() {
  test(
    'failed upload stays in the journal until the server stores it',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://odms.example'));
      var durable = false;
      dio.httpClientAdapter = FakeAdapter(
        (_) async =>
            response({'durablyAccepted': durable, 'retryLater': !durable}),
      );
      final secrets = MemorySecrets();
      final api = ApiClient('https://odms.example', secrets, transport: dio);
      final uploader = MediaUploader(api, 'staff-id');
      final pending = jsonEncode([
        {
          'path': '/api/media/example/failure',
          'body': {'eventId': 'one'},
        },
      ]);
      await secrets.write(uploader.journalKey, pending);
      await uploader.replayFailures();
      expect(await secrets.read(uploader.journalKey), pending);
      durable = true;
      await uploader.replayFailures();
      expect(await secrets.read(uploader.journalKey), isNull);
    },
  );

  test(
    'staff route policy excludes the complete flight workflow and other roles',
    () {
      for (final route in [
        'connect',
        'handover',
        'preflight',
        'flight',
        'postflight',
      ]) {
        expect(
          mayOpenMobilePath(AppRole.staff, '/staff/missions/one/$route'),
          false,
        );
      }
      expect(mayOpenMobilePath(AppRole.staff, '/manager/orders'), false);
      expect(mayOpenMobilePath(AppRole.customer, '/staff/missions'), false);
      expect(
        mayOpenMobilePath(AppRole.staff, '/staff/missions/one/checklist'),
        true,
      );
      expect(
        mayOpenMobilePath(AppRole.staff, '/staff/missions/one/media'),
        true,
      );
    },
  );
  test('native upload hashes the original file and keeps bearer credentials away from storage', () async {
    final folder = await Directory.systemTemp.createTemp('odms-upload-test-');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/evidence.jpg');
    await file.writeAsBytes([1, 2, 3, 4]);
    final backend = Dio(BaseOptions(baseUrl: 'https://api.example'));
    final paths = <String>[];
    backend.httpClientAdapter = FakeAdapter((options) async {
      paths.add(options.path);
      if (options.path.endsWith('/media-uploads')) {
        final body = object(options.data);
        expect(
          body['checksumSha256'],
          '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
        );
        expect(body['sourceType'], 'MANUAL_UPLOAD');
        expect(body['capturedAt'], '2026-11-20T03:00:00.000Z');
        return response({
          'mediaId': 'media',
          'attemptId': 'attempt',
          'status': 'UPLOADING',
          'uploadMethod': 'PUT',
          'uploadUrl': 'https://storage.example/signed',
          'uploadHeaders': {
            'content-type': ['image/jpeg'],
          },
          'attemptNumber': 1,
        });
      }
      return response(null);
    });
    final storage = Dio();
    storage.httpClientAdapter = FakeAdapter((options) async {
      expect(options.uri.host, 'storage.example');
      expect(options.headers.containsKey('Authorization'), false);
      expect(options.headers.containsKey('Cookie'), false);
      expect(options.headers['content-length'], 4);
      return ResponseBody.fromString('', 200);
    });
    final api = ApiClient(
      'https://api.example',
      MemorySecrets(),
      transport: backend,
    )..accessToken = 'backend-only';
    var progress = 0.0;
    await MediaUploader(api, 'staff', storageFactory: () => storage).upload(
      missionId: 'mission',
      deviceId: 'device',
      file: file,
      fileName: 'evidence.jpg',
      contentType: 'image/jpeg',
      capturedAt: '2026-11-20T03:00:00.000Z',
      sourceType: 'MANUAL_UPLOAD',
      onProgress: (value) => progress = value,
    );
    expect(progress, 1);
    expect(paths.last, '/api/media/media/upload-attempts/attempt/uploaded');
  });
}
