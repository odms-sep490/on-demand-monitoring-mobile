import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odms_mobile/core/models.dart';
import 'package:odms_mobile/features/customer/order_step_forms.dart';

import 'api_client_test.dart' show response;
import 'support/workflow_harness.dart';

void main() {
  for (final (kind, expectedError) in [
    ('range', 'End date must follow start date.'),
    ('deadline', 'Result deadline must follow the monitoring dates.'),
    ('recurrence', 'Enter the number of visits.'),
  ]) {
    testWidgets('booking schedule validates $kind before allowing completion', (
      tester,
    ) async {
      final backend = WorkflowBackend((request) {
        expect(request.path, '/api/preferred-times');
        return response([
          {'id': 'am', 'name': 'Morning'},
        ]);
      });
      Json? schedule;
      await showWorkflow(
        tester,
        backend,
        Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  schedule = await collectOrderSchedule(context, backend.api);
                },
                child: const Text('Book a slot'),
              );
            },
          ),
        ),
      );
      await press(tester, find.text('Book a slot'));
      final start = DateTime.now().add(const Duration(days: 15));
      final dayBefore = start.subtract(const Duration(days: 1));
      final dayAfter = start.add(const Duration(days: 1));
      await pickDate(tester, 'Start date', start);
      await pickDate(
        tester,
        'End date',
        kind == 'range' ? dayBefore : dayAfter,
      );
      await choose(tester, 'Time slot', 'Morning');
      await choose(
        tester,
        'If the visit cannot proceed',
        'Reschedule / Đổi lịch',
      );
      if (kind == 'deadline') {
        await pickDate(tester, 'Result deadline', start);
      }
      if (kind == 'recurrence') {
        await choose(tester, 'Repeat', 'Weekly / Hàng tuần');
      }
      await press(tester, find.text('Continue'));
      expect(find.text(expectedError), findsOneWidget);
      expect(schedule, isNull);
      switch (kind) {
        case 'range':
          await pickDate(tester, 'End date', dayAfter);
        case 'deadline':
          await pickDate(tester, 'Result deadline', dayAfter);
        case 'recurrence':
          await enter(tester, 'Number of visits (if repeating)', '2');
      }
      await press(tester, find.text('Continue'));
      expect(schedule, containsPair('preferredTimeId', 'am'));
      if (kind == 'recurrence') {
        expect(schedule, containsPair('recurrenceOccurrences', 2));
      }
    });
  }
}
