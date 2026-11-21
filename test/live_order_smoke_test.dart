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
      await login(api, 'customer');
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
        final manager = ApiClient(baseUrl, MemorySecrets());
        await login(manager, 'manager');
        final readiness = await manager.request(
          '/api/manager/orders/${order['id']}/readiness',
        );
        expect(object(readiness)['criteria'], isA<List>());
      } on ApiFailure catch (error) {
        fail('${error.status}: ${error.message} ${error.errors}');
      }
    },
    skip: baseUrl == null || password == null
        ? 'Requires ODMS_SMOKE_BASE_URL for an isolated backend and ODMS_SMOKE_PASSWORD.'
        : false,
  );
}

Future<void> login(ApiClient api, String role) async {
  final password = Platform.environment['ODMS_SMOKE_PASSWORD'];
  final login = object(
    await api.request(
      '/api/auth/login',
      method: 'POST',
      authenticated: false,
      body: {'email': 'seed.$role@odms.local', 'password': password},
    ),
  );
  api.accessToken = login['accessToken'] as String;
}
