import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odms_mobile/core/models.dart';
import 'package:odms_mobile/features/customer/create_order.dart';
import 'package:odms_mobile/features/customer/order_detail.dart';
import 'package:odms_mobile/features/customer/order_confirmation.dart';

import 'api_client_test.dart' show response;
import 'support/workflow_harness.dart';

void main() {
  for (final status in [201, 409, null]) {
    testWidgets('six-step booking: ${status ?? 'cancel at review'}', (
      tester,
    ) async {
      Json? submitted;
      final backend = WorkflowBackend(
        (request) => switch (request.path) {
          '/api/services' => response([
            {'id': 'warehouse', 'name': 'Warehouse inspection'},
          ]),
          '/api/services/warehouse/checklists' => response([
            {
              'checklistId': 'roof',
              'checklistVersion': 1,
              'content': 'Inspect roof',
              'required': true,
              'minimumEvidenceCount': 1,
              'requiredEvidenceType': 'IMAGE',
              'includedImageCount': 1,
            },
            {
              'checklistId': 'inactive',
              'content': 'Inactive requirement',
              'checklistActive': false,
            },
          ]),
          '/api/preferred-times' => response([
            {'id': 'morning', 'name': 'Morning', 'startTime': '08:30:00'},
          ]),
          '/api/service-deliverables' => response([
            {
              'deliverableTypeId': 'report',
              'deliverableTypeName': 'Inspection report',
            },
          ]),
          '/api/flight-area-assessment' => response({'riskLevel': 'LOW'}),
          '/api/weather/forecast' => response({'temperature': 27}),
          '/api/pricing/checklist-quote' => response({
            'total': 240000,
            'serviceName': 'Warehouse inspection',
          }),
          '/api/orders' => (() {
            expect(request.method, 'POST');
            expect(submitted, isNull);
            submitted = object(request.data);
            return response({'id': 'ord-1'}, status: status!);
          })(),
          _ => throw StateError('Unexpected request: ${request.path}'),
        },
      );
      bool? result;
      await showWorkflow(
        tester,
        backend,
        Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  result = await createOrder(context, backend.api);
                },
                child: const Text('Start booking'),
              );
            },
          ),
        ),
      );
      await press(tester, find.text('Start booking'));
      expect(find.text('Service & purpose'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
      await press(tester, find.text('Warehouse inspection'));
      await choose(tester, 'Monitoring purpose', 'Industrial inspection');
      await press(tester, find.text('Continue'));
      expect(find.text('Monitoring location'), findsOneWidget);
      await press(tester, find.text('Continue'));
      expect(find.text('Required field.'), findsOneWidget);
      await enter(tester, 'Site address', 'Warehouse District 9');
      await press(tester, find.text('Continue'));
      expect(find.text('Monitoring area'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm area'),
            )
            .onPressed,
        isNull,
      );
      await press(tester, find.text('Circle'));
      await tester.tap(find.byType(FlutterMap));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await press(tester, find.text('Confirm area'));

      expect(find.text('3. Monitoring checklist'), findsOneWidget);
      expect(find.text('Inactive requirement'), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      await press(tester, find.text('Save checklist'));

      expect(find.text('Site details and authority'), findsOneWidget);
      await choose(tester, 'Relationship to site', 'Owner / Chủ sở hữu');
      await press(
        tester,
        find.text('I have authority to request monitoring here'),
      );
      await press(tester, find.text('Continue'));
      await choose(tester, 'Airspace permit', 'No permit / Chưa có giấy phép');
      await press(tester, find.text('Continue'));

      expect(find.text('Schedule'), findsOneWidget);
      final date = DateTime.now().add(const Duration(days: 14));
      await pickDate(tester, 'Start date', date);
      await pickDate(tester, 'End date', date);
      await choose(tester, 'Time slot', 'Morning');
      await choose(
        tester,
        'If the visit cannot proceed',
        'Reschedule / Đổi lịch',
      );
      await press(tester, find.text('Continue'));

      expect(find.text('Deliverables and confirmation'), findsOneWidget);
      await press(tester, find.text('Inspection report'));
      await choose(tester, 'Data retention (days)', '30');
      await press(
        tester,
        find.text('I accept the terms and data-security commitment'),
      );
      await press(tester, find.text('Continue'));
      expect(find.text('Review your request'), findsOneWidget);
      expect(submitted, isNull);
      final weather = backend.requests.singleWhere(
        (request) => request.path == '/api/weather/forecast',
      );
      expect(weather.queryParameters['time'], '08:30');
      if (status == null) {
        await press(tester, find.byTooltip('Back'));
        expect(result, isFalse);
        expect(submitted, isNull);
        return;
      }

      final submit = find.text('Submit request');
      await tester.scrollUntilVisible(
        submit,
        260,
        scrollable: find
            .descendant(
              of: find
                  .descendant(
                    of: find.byType(SiteAdvisoryPage),
                    matching: find.byType(ListView),
                  )
                  .first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await press(tester, submit);
      expect(result, status == 201);
      expect(submitted, containsPair('address', 'Warehouse District 9'));
      expect(submitted, containsPair('serviceId', 'warehouse'));
      expect(submitted, containsPair('permitStatus', 'NONE'));
      expect(submitted, containsPair('dataRetentionDays', 30));
      expect(object(submitted!['coverageArea'])['type'], 'Polygon');
      expect(
        records(submitted!['checklistItems']).single['sourceChecklistId'],
        'roof',
      );
      expect(
        records(submitted!['deliverables']).single['deliverableTypeId'],
        'report',
      );
      if (status == 409) expect(find.text('Rejected'), findsOneWidget);
    });
  }

  testWidgets(
    'order details retry a failed load and show the backend checklist',
    (tester) async {
      var count = 0;
      final backend = WorkflowBackend((request) {
        expect(request.path, '/api/orders/ord-1');
        return ++count == 1
            ? response(null, status: 503)
            : response({
                'id': 'ord-1',
                'orderCode': 'ORD-1',
                'orderStatus': 'PENDING',
                'serviceName': 'Roof inspection',
                'checklistItems': [
                  {'content': 'Inspect roof', 'requiredEvidenceType': 'IMAGE'},
                ],
              });
      });
      await showWorkflow(
        tester,
        backend,
        const OrderDetailPage(id: 'ord-1', manager: false),
      );
      await press(tester, find.text('Retry'));
      expect(find.text('Roof inspection'), findsWidgets);
      await press(tester, find.widgetWithText(ChoiceChip, 'Monitoring'));
      expect(find.text('Inspect roof'), findsOneWidget);
      expect(find.text('Edit checklist'), findsNothing);
      expect(backend.writes, isEmpty);
    },
  );
}
