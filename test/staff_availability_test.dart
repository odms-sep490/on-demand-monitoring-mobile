import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odms_mobile/core/models.dart';
import 'package:odms_mobile/features/staff/availability_page.dart';

import 'api_client_test.dart' show response;
import 'support/workflow_harness.dart';

void main() {
  testWidgets(
    'Staff creates, edits and removes a busy session with confirmations',
    (tester) async {
      Json? session;
      final backend = WorkflowBackend((request) {
        if (request.method == 'GET') {
          expect(request.path, '/api/busy-schedules/me');
          expect(
            request.queryParameters['date'],
            matches(r'^\d{4}-\d{2}-\d{2}$'),
          );
          return response({
            'items': [?session],
            'remainingSessions': session == null ? 3 : 2,
          });
        }
        if (request.method == 'POST') {
          expect(request.path, '/api/busy-schedules');
          session = {...object(request.data), 'id': 'busy-1'};
        } else {
          expect(request.path, '/api/busy-schedules/busy-1');
          session = request.method == 'DELETE'
              ? null
              : {...object(request.data), 'id': 'busy-1'};
        }
        return response(session);
      });

      await showWorkflow(tester, backend, const AvailabilityPage());
      expect(find.text('No busy sessions registered.'), findsOneWidget);
      await press(tester, find.byType(FloatingActionButton));
      await press(tester, find.text('Continue'));
      expect(find.text('Required field.'), findsNWidgets(2));
      expect(backend.writes, isEmpty);
      await pickDate(tester, 'Date (Vietnam)', DateTime.now());
      await choose(tester, 'Session', 'Morning / Sáng');
      await enter(tester, 'Notes', 'Medical appointment');
      await press(tester, find.text('Continue'));
      expect(find.text('Medical appointment'), findsOneWidget);
      expect(find.text('2 sessions remaining'), findsOneWidget);

      await press(tester, find.text('Medical appointment'));
      await choose(tester, 'Session', 'Evening / Tối');
      await enter(tester, 'Notes', 'Updated appointment');
      await press(tester, find.text('Continue'));
      expect(find.text('Updated appointment'), findsOneWidget);

      await press(tester, find.byIcon(Icons.delete_outline));
      await press(tester, find.text('Back'));
      expect(backend.writes.map((request) => request.method), ['POST', 'PUT']);
      expect(find.text('Updated appointment'), findsOneWidget);
      await press(tester, find.byIcon(Icons.delete_outline));
      await press(tester, find.text('Remove'));
      expect(find.text('No busy sessions registered.'), findsOneWidget);
      expect(backend.writes.map((request) => request.method), [
        'POST',
        'PUT',
        'DELETE',
      ]);
    },
  );

  testWidgets('Staff can change week and retry an unavailable schedule', (
    tester,
  ) async {
    final dates = <DateTime>[];
    final backend = WorkflowBackend((request) {
      expect(request.path, '/api/busy-schedules/me');
      dates.add(DateTime.parse(request.queryParameters['date'] as String));
      return dates.length == 1
          ? response(null, status: 503)
          : response({'items': []});
    });

    await showWorkflow(tester, backend, const AvailabilityPage());
    await press(tester, find.text('Retry'));
    expect(dates[0], dates[1]);
    await press(tester, find.byIcon(Icons.chevron_right));
    expect(dates[2].difference(dates[1]).inDays, 7);
    await press(tester, find.byIcon(Icons.chevron_left));
    expect(dates.last, dates.first);
    expect(backend.writes, isEmpty);
  });
}
