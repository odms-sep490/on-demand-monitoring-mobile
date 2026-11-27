import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odms_mobile/features/customer/results_page.dart';
import 'package:odms_mobile/features/staff/checklist_page.dart';

import 'api_client_test.dart' show response;
import 'support/workflow_harness.dart';

const reviewPath = '/api/orders/ord-1/result-review';
const executionPath = '/api/missions/mission-1/checklist-executions';

void main() {
  testWidgets('Customer confirms delivery with the displayed review version', (
    tester,
  ) async {
    var accepted = false;
    final backend = WorkflowBackend((request) {
      if (request.path == reviewPath) {
        return response({
          'reviewRoundId': 'round-1',
          'roundVersion': 4,
          'canAcceptResult': !accepted,
          'items': [
            {
              'title': 'Roof survey',
              'evidence': [
                {'fileName': 'Roof.jpg', 'accessReason': 'Payment required'},
              ],
            },
          ],
        });
      }
      expect(request.path, '/api/orders/ord-1/result/accept');
      expect(request.method, 'POST');
      expect(request.data, {
        'expectedReviewRoundId': 'round-1',
        'expectedRoundVersion': 4,
      });
      accepted = true;
      return response(null);
    });
    await showWorkflow(tester, backend, const ResultsPage(orderId: 'ord-1'));
    expect(find.text('Roof.jpg'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
    await press(tester, find.text('Accept results'));
    await press(tester, find.text('Back'));
    expect(backend.writes, isEmpty);
    await press(tester, find.text('Accept results'));
    await press(tester, find.text('Accept'));
    expect(find.text('Accept results'), findsNothing);
    expect(backend.writes, hasLength(1));
  });

  testWidgets(
    'Customer revision only submits eligible items with the selected reason',
    (tester) async {
      var submitted = false;
      final backend = WorkflowBackend((request) {
        if (request.path == reviewPath) {
          return response({
            'reviewRoundId': 'round-1',
            'roundVersion': 4,
            'canSubmitRevision': !submitted,
            'items': [
              {
                'roundItemId': 'roof',
                'title': 'Roof survey',
                'canRequestRevision': true,
              },
              {
                'roundItemId': 'locked',
                'title': 'Accepted item',
                'canRequestRevision': false,
              },
            ],
          });
        }
        expect(request.path, '/api/orders/ord-1/result/revision-request');
        expect(request.method, 'POST');
        expect(request.data, containsPair('expectedRoundVersion', 4));
        expect(request.data, containsPair('reviewRoundId', 'round-1'));
        expect(
          request.data,
          containsPair('items', [
            {
              'roundItemId': 'roof',
              'reasonCode': 'MISSING_EVIDENCE',
              'note': 'Missing corner photo',
              'roundEvidenceIds': [],
            },
          ]),
        );
        submitted = true;
        return response(null);
      });
      await showWorkflow(tester, backend, const ResultsPage(orderId: 'ord-1'));
      await press(tester, find.text('Request revision'));
      expect(find.text('Accepted item'), findsNothing);
      await press(tester, find.text('Continue'));
      expect(find.text('Required field.'), findsOneWidget);
      expect(backend.writes, isEmpty);
      await press(tester, find.text('Roof survey'));
      await press(tester, find.text('Continue'));
      await choose(
        tester,
        'Roof survey — reason',
        'Missing evidence / Thiếu minh chứng',
      );
      await enter(tester, 'Details', 'Missing corner photo');
      await press(tester, find.text('Continue'));
      expect(find.text('Request revision'), findsNothing);
      expect(backend.writes, hasLength(1));
    },
  );

  for (final allowed in [false, true]) {
    testWidgets(
      'Staff checklist enforces edit permission and item version: $allowed',
      (tester) async {
        var updated = false;
        final backend = WorkflowBackend(
          (request) => switch (request.path) {
            executionPath => response({
              'executions': [
                {
                  'id': 'item-1',
                  'version': updated ? 9 : 8,
                  'content': 'Inspect roof',
                  'executionStatus': updated ? 'COMPLETED' : 'PENDING',
                  'assessmentStatus': 'NOT_ASSESSED',
                },
              ],
            }),
            '/api/missions/mission-1/permissions' => response({
              'canExecuteMonitoringChecklist': allowed,
            }),
            '$executionPath/item-1' => (() {
              expect(request.method, 'PATCH');
              expect(request.data, {
                'expectedVersion': 8,
                'executionStatus': 'COMPLETED',
                'assessmentStatus': 'NOT_ASSESSED',
                'observation': 'Inspected roof',
              });
              updated = true;
              return response(null);
            })(),
            _ => throw StateError('Unexpected request: ${request.path}'),
          },
        );
        await showWorkflow(
          tester,
          backend,
          const ChecklistPage(missionId: 'mission-1'),
        );
        expect(find.text('Inspect roof'), findsOneWidget);
        expect(find.text('Attach evidence'), findsNothing);
        if (!allowed) {
          expect(find.text('Update'), findsNothing);
          expect(backend.writes, isEmpty);
          return;
        }
        await press(tester, find.text('Update'));
        expect(
          find.widgetWithText(DropdownButtonFormField<String>, 'Assessment'),
          findsNothing,
        );
        await choose(tester, 'Execution status', 'Completed / Hoàn thành');
        await enter(tester, 'Observation', 'Inspected roof');
        await press(tester, find.text('Continue'));
        expect(find.text('COMPLETED'), findsOneWidget);
        expect(backend.writes, hasLength(1));
      },
    );
  }
}
