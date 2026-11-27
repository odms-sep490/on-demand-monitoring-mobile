import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

/// Native S3 transfer; the storage client deliberately has no ODMS credentials.
class MediaUploader {
  MediaUploader(this.api, this.userId, {this.storageFactory});
  final ApiClient api;
  final String userId;
  final Dio Function()? storageFactory;
  String get journalKey =>
      'odms.upload.failures.${api.dio.options.baseUrl}.$userId';
  Future<void> replayFailures() async {
    final raw = await api.secrets.read(journalKey);
    if (raw == null) return;
    final pending = (jsonDecode(raw) as List).map(object).toList();
    while (pending.isNotEmpty) {
      final event = pending.first;
      final acknowledgment = object(
        await api.request(
          '${event['path']}',
          method: 'POST',
          body: event['body'],
        ),
      );
      if (acknowledgment['durablyAccepted'] != true) return;
      pending.removeAt(0);
      await api.secrets.write(
        journalKey,
        pending.isEmpty ? null : jsonEncode(pending),
      );
    }
  }

  Future<void> upload({
    required String missionId,
    required String deviceId,
    required File file,
    required String fileName,
    required String contentType,
    required String capturedAt,
    required String sourceType,
    required void Function(double) onProgress,
  }) async {
    await replayFailures();
    final size = await file.length();
    if (size == 0) throw const ApiFailure('The file is empty.');
    final checksum = (await sha256.bind(file.openRead()).first).toString();
    final localId = 'mobile-$checksum';
    var plan = object(
      await api.request(
        '/api/missions/${segment(missionId)}/media-uploads',
        method: 'POST',
        body: {
          'deviceId': deviceId,
          'localMediaId': localId,
          'mediaType': contentType == 'video/mp4' ? 'VIDEO' : 'IMAGE',
          'fileName': fileName,
          'contentType': contentType,
          'fileSize': size,
          'checksumSha256': checksum,
          'capturedAt': capturedAt,
          'sourceType': sourceType,
        },
      ),
    );
    if ([
      'AVAILABLE',
      'VALIDATING',
      'PENDING_MANAGER_APPROVAL',
    ].contains(plan['status'])) {
      onProgress(1);
      return;
    }
    if (['RETRY_REQUIRED', 'UPLOAD_FAILED'].contains(plan['status'])) {
      plan = object(
        await api.request(
          '/api/media/${segment('${plan['mediaId']}')}/upload-attempts',
          method: 'POST',
        ),
      );
    }
    final attempt =
        '/api/media/${segment('${plan['mediaId']}')}/upload-attempts/${segment('${plan['attemptId']}')}';
    if (plan['attemptId'] == null ||
        !['PUT', 'MULTIPART'].contains(plan['uploadMethod'])) {
      throw const ApiFailure(
        'This file needs a manual upload task or a new server upload session.',
      );
    }
    final storage =
        storageFactory?.call() ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(minutes: 5),
            sendTimeout: const Duration(minutes: 30),
          ),
        );
    var transferred = false;
    try {
      Future<String?> put(Json signed, int start, int end) async {
        final uri = Uri.tryParse('${signed['uploadUrl']}');
        if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
          throw const ApiFailure('Invalid storage upload URL.');
        }
        final headers = <String, dynamic>{};
        for (final entry in object(signed['uploadHeaders']).entries) {
          headers[entry.key] = entry.value is List
              ? (entry.value as List).join(',')
              : entry.value;
        }
        headers[Headers.contentLengthHeader] = end - start;
        final result = await storage.put<Object?>(
          uri.toString(),
          data: file.openRead(start, end),
          options: Options(headers: headers, followRedirects: false),
          onSendProgress: (sent, _) => onProgress((start + sent) / size),
        );
        return result.headers.value('etag');
      }

      if (plan['uploadMethod'] == 'PUT') {
        await put(plan, 0, size);
        transferred = true;
        await api.request('$attempt/uploaded', method: 'POST');
      } else {
        final parts = <Json>[];
        final partSize = (plan['partSizeBytes'] as num).toInt(),
            count = (plan['partCount'] as num).toInt();
        if (partSize <= 0 || count != (size / partSize).ceil()) {
          throw const ApiFailure('Invalid multipart upload plan.');
        }
        for (var number = 1; number <= count; number++) {
          final signed = object(
            await api.request('$attempt/parts/$number/url', method: 'POST'),
          );
          final start = (number - 1) * partSize,
              end = number * partSize > size ? size : number * partSize;
          final etag = await put(signed, start, end);
          if (etag == null) {
            throw const ApiFailure('Storage did not return the part ETag.');
          }
          parts.add({'partNumber': number, 'eTag': etag});
        }
        transferred = true;
        await api.request(
          '$attempt/complete-multipart',
          method: 'POST',
          body: {'parts': parts},
        );
      }
      onProgress(1);
    } catch (failure) {
      final event = {
        'eventId': newRequestId(),
        'category': transferred ? 'TRANSFER_ACK_LOST' : 'TRANSFER_FAILED',
        'missionId': missionId,
        'mediaId': plan['mediaId'],
        'attemptId': plan['attemptId'],
        'localMediaId': localId,
        'attemptNumber': plan['attemptNumber'],
        'checksumSha256': checksum,
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
        'code': 'MOBILE_TRANSFER_FAILED',
        'message': '$failure'.substring(
          0,
          '$failure'.length > 400 ? 400 : '$failure'.length,
        ),
      };
      // Retain the failure event encrypted if its delivery to the server fails.
      final raw = await api.secrets.read(journalKey);
      final pending = raw == null ? <Object>[] : jsonDecode(raw) as List;
      pending.add({'path': '$attempt/failures', 'body': event});
      await api.secrets.write(journalKey, jsonEncode(pending));
      try {
        await replayFailures();
      } catch (_) {
        /* Replay on the next upload by this user. */
      }
      rethrow;
    } finally {
      storage.close();
    }
  }
}
