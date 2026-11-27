import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odms_mobile/core/models.dart';
import 'package:odms_mobile/features/maintenance/maintenance_page.dart';
import 'package:odms_mobile/features/profile/profile_page.dart';
import 'package:odms_mobile/features/staff/licenses_page.dart';

import 'api_client_test.dart' show response;
import 'support/workflow_harness.dart';

void main() {
  testWidgets(
    'Staff loads its own qualifications, creates and edits a record',
    (tester) async {
      Json? license;
      final backend = WorkflowBackend((request) {
        if (request.method == 'GET') {
          expect(request.path, '/api/staff-licenses/users/user-1');
          return response([?license]);
        }
        final payload = object(request.data);
        expect(payload['userId'], 'user-1');
        expect(
          request.path,
          request.method == 'POST'
              ? '/api/staff-licenses'
              : '/api/staff-licenses/license-1',
        );
        license = {...payload, 'id': 'license-1'};
        return response(license);
      });
      await showWorkflow(
        tester,
        backend,
        const LicensesPage(),
        role: AppRole.staff,
      );
      expect(find.text('No qualifications added.'), findsOneWidget);
      await press(tester, find.byType(FloatingActionButton));
      await choose(tester, 'Type', 'Technical / Kỹ thuật');
      await enter(tester, 'License number', 'CERT-123');
      await enter(tester, 'License name', 'Technical certificate');
      await enter(tester, 'Issuing authority', 'Test authority');
      await pickDate(tester, 'Issued date', DateTime.now());
      await press(tester, find.text('Continue'));
      expect(find.text('Technical certificate'), findsOneWidget);
      expect(license, containsPair('licenseNumber', 'CERT-123'));
      await press(tester, find.text('Edit'));
      await enter(tester, 'License name', 'Updated certificate');
      await press(tester, find.text('Continue'));
      expect(find.text('Updated certificate'), findsOneWidget);
      expect(backend.writes.map((request) => request.method), ['POST', 'PUT']);
    },
  );

  testWidgets(
    'Staff resolves its maintenance ticket and the action disappears',
    (tester) async {
      var resolved = false;
      final backend = WorkflowBackend(
        (request) => switch (request.path) {
          '/api/maintenance-tickets' => (() {
            expect(request.queryParameters, {'staffId': 'user-1'});
            return response([
              {'id': 'repair-1', 'title': 'Replace cover'},
            ]);
          })(),
          '/api/maintenance-tickets/repair-1' => response({
            'title': 'Replace cover',
            'status': resolved ? 'RESOLVED' : 'IN_PROGRESS',
            'assignedTechnicianId': 'user-1',
          }),
          '/api/maintenance-tickets/repair-1/resolve' => (() {
            expect(request.method, 'PATCH');
            expect(request.data, {
              'resolutionNotes': 'Replaced cover',
              'newDeviceStatus': 'AVAILABLE',
            });
            resolved = true;
            return response(null);
          })(),
          _ => throw StateError('Unexpected request: ${request.path}'),
        },
      );
      await showWorkflow(
        tester,
        backend,
        const MaintenancePage(),
        role: AppRole.staff,
      );
      await press(tester, find.text('Replace cover'));
      await press(tester, find.text('Resolve'));
      await enter(tester, 'Repair notes', 'Replaced cover');
      await choose(tester, 'Device status', 'Available / Sẵn sàng');
      await press(tester, find.text('Continue'));
      expect(find.text('Resolve'), findsNothing);
      expect(backend.writes, hasLength(1));
    },
  );

  for (final role in [AppRole.customer, AppRole.staff]) {
    testWidgets(
      '${role.name} profile writes the fields available to its role',
      (tester) async {
        var name = 'Test User';
        final backend = WorkflowBackend((request) {
          expect(request.path, '/api/users/me');
          if (request.method == 'PATCH') {
            expect(request.data, containsPair('fullName', 'Updated User'));
            expect(
              object(request.data).containsKey('companyName'),
              role == AppRole.customer,
            );
            name = 'Updated User';
          }
          return response({'fullName': name, 'email': 'test@example.com'});
        });
        await showWorkflow(tester, backend, const ProfilePage(), role: role);
        await press(tester, find.text('Edit profile'));
        expect(
          field('Company'),
          role == AppRole.customer ? findsOneWidget : findsNothing,
        );
        if (role == AppRole.customer) {
          await enter(tester, 'Company', 'Test Company');
        }
        await enter(tester, 'Full name', 'Updated User');
        await press(tester, find.text('Continue'));
        expect(find.text('Updated User'), findsOneWidget);
        expect(backend.writes.single.method, 'PATCH');
      },
    );
  }
}
