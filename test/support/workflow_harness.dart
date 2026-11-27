import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:odms_mobile/app/theme.dart';
import 'package:odms_mobile/core/api_client.dart';
import 'package:odms_mobile/core/providers.dart';
import 'package:odms_mobile/core/models.dart';
import 'package:odms_mobile/features/auth/session.dart';

import '../api_client_test.dart' show FakeAdapter, MemorySecrets, response;

class WorkflowBackend {
  WorkflowBackend(FutureOr<ResponseBody> Function(RequestOptions) handle) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
    dio.httpClientAdapter = FakeAdapter((request) async {
      if (request.path == '/api/auth/csrf') return response('test-csrf');
      requests.add(request);
      return handle(request);
    });
    api = ApiClient('https://api.example', MemorySecrets(), transport: dio)
      ..accessToken = 'test-access-token';
    addTearDown(() => dio.close(force: true));
  }

  late final ApiClient api;
  final requests = <RequestOptions>[];

  Iterable<RequestOptions> get writes =>
      requests.where((request) => request.method != 'GET');
}

Future<void> showWorkflow(
  WidgetTester tester,
  WorkflowBackend backend,
  Widget page, {
  AppRole? role,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiProvider.overrideWithValue(backend.api),
        if (role != null)
          sessionProvider.overrideWith((ref) {
            final session = SessionController(backend.api)
              ..user = AppUser(
                id: 'user-1',
                email: 'test@example.com',
                fullName: 'Test User',
                role: role,
              )
              ..status = SessionStatus.authenticated;
            ref.onDispose(session.dispose);
            return session;
          }),
      ],
      child: MaterialApp(theme: odmsTheme(), home: page),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> choose(WidgetTester tester, String label, String option) async {
  final control = find.ancestor(
    of: find.text(label),
    matching: find.byType(DropdownButtonFormField<String>),
  );
  await press(tester, control);
  await press(tester, find.text(option).last);
}

Future<void> pickDate(WidgetTester tester, String label, DateTime date) async {
  await press(tester, field(label));
  final dialog = find.byType(DatePickerDialog);
  await press(
    tester,
    find.descendant(of: dialog, matching: find.byIcon(Icons.edit_outlined)),
  );
  await tester.enterText(
    find.descendant(of: dialog, matching: find.byType(TextField)),
    '${date.month}/${date.day}/${date.year}',
  );
  await press(tester, find.text('OK'));
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  final input = field(label);
  await tester.ensureVisible(input);
  await tester.enterText(input, value);
  await tester.pumpAndSettle();
}
