import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:odms_mobile/app/app.dart';
import 'package:odms_mobile/app/theme.dart';
import 'package:odms_mobile/core/api_client.dart';
import 'package:odms_mobile/core/models.dart';
import 'package:odms_mobile/features/auth/session.dart';
import 'package:odms_mobile/features/devices/device_pages.dart';
import 'package:odms_mobile/shared/area_picker.dart';

import 'api_client_test.dart' show FakeAdapter, MemorySecrets, response;

void main() {
  test(
    'coverage area uses GeoJSON longitude/latitude order and closes the ring',
    () {
      final polygon = polygonPayload(const [
        LatLng(10, 106),
        LatLng(11, 106),
        LatLng(11, 107),
      ]);
      expect(polygon['coordinates'], [
        [
          [106.0, 10.0],
          [106.0, 11.0],
          [107.0, 11.0],
          [106.0, 10.0],
        ],
      ]);
      expect(
        () => polygonPayload(const [LatLng(10, 106), LatLng(11, 106)]),
        throwsFormatException,
      );
      expect(
        () => polygonPayload(const [
          LatLng(10, 106),
          LatLng(11, 106),
          LatLng(12, 106),
        ]),
        throwsFormatException,
      );
    },
  );
  test('device catalogue loads every backend page', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
    final requested = <int>[];
    dio.httpClientAdapter = FakeAdapter((options) async {
      final page = options.queryParameters['page'] as int;
      requested.add(page);
      return response({
        'items': [
          {'id': '$page', 'name': 'Device $page'},
        ],
        'last': page == 2,
        'totalPages': 3,
      });
    });
    final items = await allPages(
      ApiClient('https://api.example', MemorySecrets(), transport: dio),
      '/api/drones',
    );
    expect(items.map((e) => e['id']), ['0', '1', '2']);
    expect(requested, [0, 1, 2]);
  });
  for (final role in AppRole.values) {
    testWidgets('${role.name} sees its own mobile workspace at phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session =
          SessionController(ApiClient('https://api.example', MemorySecrets()))
            ..user = AppUser(
              id: '1',
              email: 'test@example.com',
              fullName: 'Test User',
              role: role,
            )
            ..status = SessionStatus.authenticated;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sessionProvider.overrideWithValue(session)],
          child: MaterialApp(
            theme: odmsTheme(),
            locale: const Locale('vi'),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('vi'), Locale('en')],
            home: const HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test User'), findsOneWidget);
      if (role == AppRole.customer) {
        expect(find.text('Đơn hàng của tôi'), findsOneWidget);
        expect(find.text('Tổng quan'), findsNothing);
      }
      if (role == AppRole.manager) {
        expect(find.text('Tổng quan'), findsOneWidget);
        expect(find.text('Đơn hàng của tôi'), findsNothing);
      }
      if (role == AppRole.staff) {
        expect(find.text('Tổng quan'), findsNothing);
        expect(find.text('Flight control'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    });
  }
}
