import 'package:flutter_test/flutter_test.dart';
import 'package:odms_mobile/features/customer/finance_page.dart';
import 'package:odms_mobile/features/customer/site_advisory_data.dart';

import 'api_client_test.dart' show response;
import 'support/workflow_harness.dart';

const orderPath = '/api/orders/ord-1';

void main() {
  test(
    'advisory preserves weather, risk, and quote request contracts',
    () async {
      final backend = WorkflowBackend(
        (request) => switch (request.path) {
          '/api/preferred-times' => response([
            {'id': 'am', 'startTime': '08:30:00'},
          ]),
          '/api/flight-area-assessment' => response({
            'assessment': {'riskLevel': 'LOW'},
          }),
          '/api/weather/forecast' => response({'status': 'AVAILABLE'}),
          '/api/pricing/checklist-quote' => response({'total': 250000}),
          _ => throw StateError('Unexpected request: ${request.path}'),
        },
      );
      final result = await loadSiteAdvisory(
        backend.api,
        confirm: true,
        area: {'areaHa': 3.5},
        order: {
          'latitude': 10.8,
          'longitude': 106.7,
          'altitudeM': 70,
          'preferredTimeId': 'am',
          'preferredDateFrom': '2027-01-15',
          'serviceId': 'survey',
          'estimatedLengthM': 2400,
          'checklistItems': [
            {
              'sourceChecklistId': 'roof',
              'content': 'Roof',
              'contentOverride': 'Inspect roof',
              'requestedImageCount': 2,
            },
          ],
          'deliverables': [
            {
              'requirement': {'radius_m': 250},
            },
          ],
          'recurrenceType': 'NONE',
          'recurrenceOccurrences': 4,
          'resultFormats': ['PHOTO'],
          'permitStatus': 'NONE',
        },
      );

      expect(result.keys, unorderedEquals(['weather', 'risk', 'quote']));
      final risk = backend.requests.singleWhere(
        (r) => r.path == '/api/flight-area-assessment',
      );
      expect(risk.queryParameters, {
        'latitude': 10.8,
        'longitude': 106.7,
        'radiusMeters': 250,
        'requestedAltitudeAgl': 70,
        'includeOsm': true,
      });
      final weather = backend.requests.singleWhere(
        (r) => r.path == '/api/weather/forecast',
      );
      expect(weather.queryParameters, {
        'latitude': 10.8,
        'longitude': 106.7,
        'date': '2027-01-15',
        'time': '08:30',
      });
      final quote = backend.writes.single;
      expect(quote.path, '/api/pricing/checklist-quote');
      expect(quote.data, {
        'serviceId': 'survey',
        'items': [
          {
            'sourceChecklistId': 'roof',
            'content': 'Inspect roof',
            'requestedImageCount': 2,
          },
        ],
        'areaHa': 3.5,
        'lengthKm': 2.4,
        'altitudeM': 70,
        'occurrences': 1,
        'resultFormats': ['PHOTO'],
        'permitStatus': 'NONE',
      });
    },
  );

  test('incomplete location omits risk and weather requests while still loading quote', () async {
    final backend = WorkflowBackend(
      (request) => switch (request.path) {
        '/api/preferred-times' => response([]),
        '/api/pricing/checklist-quote' => response({'total': 0}),
        _ => throw StateError('Unexpected request: ${request.path}'),
      },
    );
    final result = await loadSiteAdvisory(
      backend.api,
      order: {},
      area: {},
      confirm: true,
    );
    expect(result['riskError'], 'LOCATION_INCOMPLETE');
    expect(result['weatherError'], contains('no complete location'));
    expect(result['quote'], {'total': 0});
    expect(
      backend.requests.map((r) => r.path),
      unorderedEquals(['/api/preferred-times', '/api/pricing/checklist-quote']),
    );
  });

  test(
    'failed weather leaves the risk assessment available when viewing an order',
    () async {
      final backend = WorkflowBackend(
        (request) => switch (request.path) {
          '/api/preferred-times' => response([
            {'id': 'am', 'startTime': '08:30:00'},
          ]),
          '/api/flight-area-assessment' => response({
            'assessment': {'riskLevel': 'LOW'},
          }),
          '/api/weather/forecast' => response(null, status: 503),
          _ => throw StateError('Unexpected request: ${request.path}'),
        },
      );
      final result = await loadSiteAdvisory(
        backend.api,
        confirm: false,
        area: {},
        order: {
          'latitude': 10.8,
          'longitude': 106.7,
          'radiusM': 250,
          'preferredTimeId': 'am',
          'preferredDateFrom': '2027-01-15',
        },
      );
      expect(result['risk'], {
        'assessment': {'riskLevel': 'LOW'},
      });
      expect(result['weatherError'], contains('Rejected'));
      expect(backend.writes, isEmpty);
    },
  );

  testWidgets('finance treats missing resources as an empty quote state', (
    tester,
  ) async {
    final backend = WorkflowBackend((request) {
      expect(request.method, 'GET');
      return response(null, status: 404);
    });
    await showWorkflow(tester, backend, const FinancePage(orderId: 'ord-1'));
    expect(find.text('No quote has been issued yet.'), findsOneWidget);
    expect(find.text('Pay deposit'), findsNothing);
    expect(backend.requests.map((r) => r.path), [
      '$orderPath/quote',
      '$orderPath/invoice',
      '$orderPath/mission-payment-milestones',
    ]);
  });

  testWidgets(
    'quote acceptance refreshes finance and gates deposit on contract',
    (tester) async {
      var accepted = false;
      final backend = WorkflowBackend(
        (request) => switch (request.path) {
          '$orderPath/quote' => response({
            'id': 'quote-1',
            'status': accepted ? 'ACCEPTED' : 'APPROVED',
          }),
          '$orderPath/invoice' => response({
            'id': 'inv-1',
            'status': 'ISSUED',
            'contractRequired': true,
            'depositStatus': 'UNPAID',
          }),
          '$orderPath/mission-payment-milestones' => response({
            'milestones': [],
          }),
          '$orderPath/quotes/quote-1/accept' => (() {
            expect(request.method, 'POST');
            accepted = true;
            return response({});
          })(),
          _ => throw StateError('Unexpected request: ${request.path}'),
        },
      );
      await showWorkflow(tester, backend, const FinancePage(orderId: 'ord-1'));
      expect(find.text('Pay deposit'), findsNothing);
      await press(tester, find.text('Accept quote'));
      expect(find.text('Accept quote'), findsNothing);
      expect(find.text('ACCEPTED'), findsOneWidget);
      expect(backend.writes.single.path, '$orderPath/quotes/quote-1/accept');
      expect(
        backend.requests.where((r) => r.path == '$orderPath/quote'),
        hasLength(2),
      );
    },
  );
}
