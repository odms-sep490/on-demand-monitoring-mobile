import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odms_mobile/core/models.dart';
import 'package:odms_mobile/features/auth/auth_page.dart';
import 'package:odms_mobile/features/auth/session.dart';
import 'package:odms_mobile/features/missions/mission_detail.dart';
import 'package:odms_mobile/features/notifications/notifications_page.dart';
import 'package:odms_mobile/features/support/support_pages.dart';

import 'api_client_test.dart' show response;
import 'support/workflow_harness.dart';

void main() {
  testWidgets('registration and OTP resend submit customer-only payloads', (
    tester,
  ) async {
    final backend = WorkflowBackend((request) => response(null));
    await showWorkflow(tester, backend, const AuthPage());
    await press(tester, find.text('Create an account'));
    await enter(tester, 'Full name', 'New Customer');
    await enter(tester, 'Email', 'customer@example.com');
    await enter(tester, 'Password', 'fake-example-password');
    await press(tester, find.text('Continue'));
    expect(find.text('Verify your email'), findsOneWidget);

    await press(tester, find.text('Resend code'));
    expect(find.text('A new code has been sent.'), findsOneWidget);
    await enter(tester, 'Verification code', '123456');
    await press(tester, find.text('Continue'));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email verified. Sign in to continue.'), findsOneWidget);

    expect(backend.writes.map((r) => r.path), [
      '/api/auth/register',
      '/api/auth/resend-otp',
      '/api/auth/verify-otp',
    ]);
    expect(backend.writes.first.data, {
      'email': 'customer@example.com',
      'fullName': 'New Customer',
      'password': 'fake-example-password',
      'role': 'CUSTOMER',
    });
    expect(backend.writes.last.data, {
      'email': 'customer@example.com',
      'otpCode': '123456',
    });
  });

  testWidgets('password recovery handles a rejected code and retries', (
    tester,
  ) async {
    var attempts = 0;
    final backend = WorkflowBackend(
      (request) => switch (request.path) {
        '/api/auth/forgot-password' => response(null),
        '/api/auth/reset-password' =>
          ++attempts == 1 ? response(null, status: 422) : response(null),
        _ => throw StateError('Unexpected request: ${request.path}'),
      },
    );
    await showWorkflow(tester, backend, const AuthPage());
    await press(tester, find.text('Forgot password?'));
    await enter(tester, 'Email', 'customer@example.com');
    await press(tester, find.text('Continue'));
    expect(find.text('Set a new password'), findsOneWidget);
    await enter(tester, 'Verification code', '000000');
    await enter(tester, 'Password', 'another-example-password');
    await press(tester, find.text('Continue'));
    expect(find.text('Rejected'), findsOneWidget);
    await enter(tester, 'Verification code', '123456');
    await press(tester, find.text('Continue'));
    expect(find.text('Password reset. Sign in to continue.'), findsOneWidget);
    expect(backend.writes.last.data, {
      'email': 'customer@example.com',
      'otpCode': '123456',
      'newPassword': 'another-example-password',
    });
  });

  testWidgets(
    'sign-in validates email and recovers after rejected credentials',
    (tester) async {
      var attempts = 0;
      final backend = WorkflowBackend((request) {
        expect(request.path, '/api/auth/login');
        return ++attempts == 1
            ? response(null, status: 401)
            : response({
                'accessToken': 'authenticated-token',
                'user': {
                  'id': 'customer-1',
                  'email': 'customer@example.com',
                  'fullName': 'Customer',
                  'role': 'CUSTOMER',
                },
              });
      });
      await showWorkflow(tester, backend, const AuthPage());
      await enter(tester, 'Email', 'invalid');
      await enter(tester, 'Password', 'test-password');
      await press(tester, find.text('Continue'));
      expect(find.text('Enter a valid email.'), findsOneWidget);
      expect(backend.writes, isEmpty);
      await enter(tester, 'Email', 'customer@example.com');
      await press(tester, find.text('Continue'));
      expect(find.text('Rejected'), findsOneWidget);
      await press(tester, find.text('Continue'));
      final context = tester.element(find.byType(AuthPage));
      final session = ProviderScope.containerOf(context).read(sessionProvider);
      expect(session.status, SessionStatus.authenticated);
      expect(session.user?.role, AppRole.customer);
      expect(backend.writes, hasLength(2));
    },
  );

  testWidgets(
    'Customer creates a support ticket and stays on the refreshed list',
    (tester) async {
      var created = false;
      final backend = WorkflowBackend((request) {
        expect(request.path, '/api/support-tickets');
        if (request.method == 'GET') {
          return response(
            created
                ? [
                    {'id': 'ticket-1', 'subject': 'Order question'},
                  ]
                : [],
          );
        }
        expect(request.method, 'POST');
        expect(request.data, {
          'subject': 'Order question',
          'description': 'Where is my report?',
          'category': 'ORDERS',
          'priority': 'NORMAL',
        });
        created = true;
        return response(null);
      });
      await showWorkflow(
        tester,
        backend,
        const SupportPage(),
        role: AppRole.customer,
      );
      await press(tester, find.byType(FloatingActionButton));
      await enter(tester, 'Subject', 'Order question');
      await enter(tester, 'Description', 'Where is my report?');
      await choose(tester, 'Category', 'Orders / Đơn hàng');
      await press(tester, find.text('Continue'));
      expect(find.byType(SupportPage), findsOneWidget);
      expect(find.text('Order question'), findsOneWidget);
      expect(backend.requests.map((request) => request.method), [
        'GET',
        'POST',
        'GET',
      ]);
    },
  );

  testWidgets(
    'Staff support list has no Customer ticket creation or FAQ actions',
    (tester) async {
      final backend = WorkflowBackend((request) {
        expect(request.path, '/api/support-tickets');
        return response([]);
      });
      await showWorkflow(
        tester,
        backend,
        const SupportPage(),
        role: AppRole.staff,
      );
      expect(find.text('FAQ'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(backend.writes, isEmpty);
    },
  );

  testWidgets(
    'Customer can reply on an open ticket and loses reply when closed',
    (tester) async {
      var answered = false;
      final backend = WorkflowBackend((request) {
        if (request.method == 'GET') {
          expect(request.path, '/api/support-tickets/ticket-1');
          return response({
            'subject': 'Order question',
            'status': answered ? 'CLOSED' : 'OPEN',
            'messages': answered
                ? [
                    {
                      'senderName': 'Test User',
                      'content': 'Thank you.',
                      'createdAt': '2026-11-27',
                    },
                  ]
                : [],
          });
        }
        expect(request.path, '/api/support-tickets/ticket-1/messages');
        expect(request.method, 'POST');
        expect(request.data, {'content': 'Thank you.'});
        answered = true;
        return response(null);
      });
      await showWorkflow(
        tester,
        backend,
        const TicketPage(id: 'ticket-1'),
        role: AppRole.customer,
      );
      expect(find.text('Update status'), findsNothing);
      await press(tester, find.text('Reply'));
      await enter(tester, 'Message', 'Thank you.');
      await press(tester, find.text('Continue'));
      expect(find.text('Thank you.'), findsOneWidget);
      expect(find.text('Reply'), findsNothing);
    },
  );

  testWidgets('Staff ignores order notifications outside its workspace', (
    tester,
  ) async {
    final backend = WorkflowBackend((request) {
      expect(request.path, '/api/notifications');
      expect(request.queryParameters, {'limit': 30});
      return response([
        {
          'title': 'Order updated',
          'type': 'ORDER_UPDATED',
          'entityId': 'ord-1',
        },
      ]);
    });
    await showWorkflow(
      tester,
      backend,
      const NotificationsPage(),
      role: AppRole.staff,
    );
    await press(tester, find.text('Order updated'));
    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(backend.requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final canUpload in [false, true]) {
    testWidgets(
      'Staff mission evidence visibility follows permissions: $canUpload',
      (tester) async {
        final backend = WorkflowBackend(
          (request) => switch (request.path) {
            '/api/missions/mission-1' => response({
              'missionCode': 'MSN-1',
              'scopeLabel': 'Inspect roof',
            }),
            '/api/missions/mission-1/permissions' => response({
              'canUploadMedia': canUpload,
              'canStartFlight': true,
            }),
            _ => throw StateError('Unexpected request: ${request.path}'),
          },
        );
        await showWorkflow(
          tester,
          backend,
          const MissionDetailPage(id: 'mission-1'),
          role: AppRole.staff,
        );
        expect(find.text('Monitoring checklist'), findsOneWidget);
        expect(
          find.text('Evidence files'),
          canUpload ? findsOneWidget : findsNothing,
        );
        expect(find.text('Start flight'), findsNothing);
        expect(backend.writes, isEmpty);
      },
    );
  }
}
