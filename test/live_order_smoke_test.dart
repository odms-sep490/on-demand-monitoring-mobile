import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:odms_mobile/core/api_client.dart';
import 'package:odms_mobile/core/models.dart';
import 'package:odms_mobile/features/customer/checklist_editor.dart';
import 'package:odms_mobile/features/customer/order_draft.dart';

import 'api_client_test.dart' show MemorySecrets;

void main() {
  final baseUrl = Platform.environment['ODMS_SMOKE_BASE_URL'];
  final password = Platform.environment['ODMS_SMOKE_PASSWORD'];
  test(
    'real ODMS customer creates and retrieves a test order',
    () async {
      final api = ApiClient(baseUrl!, MemorySecrets());
      await login(
        api,
        Platform.environment['ODMS_SMOKE_CUSTOMER_EMAIL'] ??
            'seed.customer@odms.local',
      );
      final services = records(
        await api.request('/api/services', query: {'activeOnly': true}),
      );
      final times = records(await api.request('/api/preferred-times'));
      expect(
        records(await api.request('/api/support-tickets/faq-articles')),
        isNotEmpty,
      );
      final service = services.first['id'];
      expect(service, isNotNull);
      final deliverables = records(
        await api.request(
          '/api/service-deliverables',
          query: {'serviceId': service},
        ),
      );
      final templates = records(
        await api.request('/api/services/$service/checklists'),
      );
      final date = DateTime.now()
          .add(const Duration(days: 14))
          .toIso8601String()
          .split('T')
          .first;
      final body = OrderDraft(
        service: {'serviceId': service},
        details: {
          'title': 'Flutter Customer smoke test',
          'address': 'Quận 9, Thành phố Hồ Chí Minh',
          'preferredDateFrom': date,
          'preferredDateTo': date,
          'preferredTimeId': times.first['id'],
          'flightPurpose': 'AREA_MONITORING',
          'monitoringRelationship': 'OWNER',
          'monitoringAuthorizationConfirmed': true,
          'termsAccepted': true,
          'dataRetentionDays': '30',
          'recurrenceType': 'NONE',
          'deliverableIds': [deliverables.first['deliverableTypeId']],
        },
        area: {
          'longitude': 106.8,
          'latitude': 10.8,
          'coverageArea': {
            'type': 'Polygon',
            'coordinates': [
              [
                [106.799, 10.799],
                [106.801, 10.799],
                [106.801, 10.801],
                [106.799, 10.801],
                [106.799, 10.799],
              ],
            ],
          },
        },
        compliance: {
          'permitStatus': 'NONE',
          'resultFormats': ['PHOTO'],
          'deliveryMethods': ['DOWNLOAD'],
        },
        checklist: [
          for (final row in templates)
            if (row['serviceActive'] != false &&
                row['checklistActive'] != false)
              checklistUpdateItem({
                'sourceChecklistVersion': row['checklistVersion'],
                'minimumEvidenceCount': row['minimumEvidenceCount'],
                'requiredEvidenceType': row['requiredEvidenceType'],
                'sourceChecklistId': row['checklistId'],
                'content': row['content'],
                'requestedImageCount': row['includedImageCount'] ?? 0,
                'requestedVideoCount': row['includedVideoCount'] ?? 0,
              }),
        ],
      ).toRequestJson();
      try {
        final order = object(
          await api.request('/api/orders', method: 'POST', body: body),
        );
        expect(order['id'], isNotNull);
        final list = records(await api.request('/api/orders/mine'));
        expect(list.any((row) => row['id'] == order['id']), isTrue);
        final detail = object(await api.request('/api/orders/${order['id']}'));
        expect(detail['id'], order['id']);
        expect(detail['orderStatus'], 'PENDING');
        expect(object(detail['coverageArea'])['type'], 'Polygon');
        final library = await api.request('/api/customer/available-media');
        expect(library, isA<List>());
        expect(
          await api.request('/api/customer/ai/change-analyses'),
          isA<List>(),
        );
      } on ApiFailure catch (error) {
        fail('${error.status}: ${error.message} ${error.errors}');
      }
    },
    skip: baseUrl == null || password == null
        ? 'Requires ODMS_SMOKE_BASE_URL for an isolated backend and ODMS_SMOKE_PASSWORD.'
        : false,
  );
  test(
    'real ODMS Staff reads assignments and maintains its own busy schedule',
    () async {
      final api = ApiClient(baseUrl!, MemorySecrets());
      await login(
        api,
        Platform.environment['ODMS_SMOKE_STAFF_EMAIL'] ??
            'seed.drone.operator@odms.local',
      );
      final profile = AppUser.fromJson(
        object(await api.request('/api/users/me')),
      );
      expect(profile.role, AppRole.staff);
      expect(await api.request('/api/missions/mine'), isA<List>());
      expect(
        await api.request('/api/staff-licenses/users/${segment(profile.id)}'),
        isA<List>(),
      );
      final date = DateTime.now()
          .add(const Duration(days: 15))
          .toIso8601String()
          .split('T')
          .first;
      final week = object(
        await api.request('/api/busy-schedules/me', query: {'date': date}),
      );
      final busy = records(week['items']);
      final session = ['MORNING', 'AFTERNOON', 'EVENING'].firstWhere(
        (candidate) => !busy.any(
          (row) => row['date'] == date && row['session'] == candidate,
        ),
      );
      final body = {
        'date': date,
        'session': session,
        'notes': 'Flutter live integration',
      };
      final created = object(
        await api.request('/api/busy-schedules', method: 'POST', body: body),
      );
      final id = created['id'] as String;
      final path = '/api/busy-schedules/${segment(id)}';
      try {
        expect(object(await api.request(path))['session'], session);
        final updated = object(
          await api.request(
            path,
            method: 'PUT',
            body: {...body, 'notes': 'Flutter live integration updated'},
          ),
        );
        expect(updated['notes'], 'Flutter live integration updated');
      } finally {
        await api.request(path, method: 'DELETE');
      }
      final after = object(
        await api.request('/api/busy-schedules/me', query: {'date': date}),
      );
      expect(records(after['items']).any((row) => row['id'] == id), isFalse);
    },
    skip: baseUrl == null || password == null
        ? 'Requires ODMS_SMOKE_BASE_URL for an isolated backend and ODMS_SMOKE_PASSWORD.'
        : false,
  );
}

Future<void> login(ApiClient api, String email) async {
  final password = Platform.environment['ODMS_SMOKE_PASSWORD'];
  final login = object(
    await api.request(
      '/api/auth/login',
      method: 'POST',
      authenticated: false,
      body: {'email': email, 'password': password},
    ),
  );
  api.accessToken = login['accessToken'] as String;
}
