import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:odms_mobile/features/customer/checklist_editor.dart';

import 'api_client_test.dart' show FakeAdapter, MemorySecrets, response;

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('EXPORT_PREVIEWS')) {
      final root = Platform.environment['FLUTTER_ROOT'];
      if (root != null) {
        final font = FontLoader('Roboto')
          ..addFont(
            File('$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf')
                .readAsBytes()
                .then((bytes) => ByteData.view(bytes.buffer)),
          );
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            File(
              '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
          );
        await icons.load();
      }
    }
  });
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
      if (const bool.fromEnvironment('EXPORT_PREVIEWS')) {
        await tester.runAsync(() async {
          final element = find.byType(HomePage).evaluate().single;
          RenderObject? render = element.renderObject;
          while (render is! RenderRepaintBoundary && render != null) {
            render = render.parent;
          }
          if (render is RenderRepaintBoundary) {
            final image = await render.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('build/previews')
              ..createSync(recursive: true);
            File('${folder.path}/${role.name}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          }
        });
      }

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
  test(
    'checklist updates preserve snapshot identity and use one evidence policy',
    () {
      final media = checklistUpdateItem({
        'id': 'snapshot',
        'sourceChecklistId': 'template',
        'content': 'Inspect roof',
        'requestedImageCount': 2,
        'requestedVideoCount': 1,
        'minimumEvidenceCount': 9,
      });
      expect(media['existingItemId'], 'snapshot');
      expect(media.containsKey('sourceChecklistId'), false);
      expect(media.containsKey('minimumEvidenceCount'), false);
      expect(media['requestedImageCount'], 2);
      final custom = checklistUpdateItem({'content': 'Inspect wall'});
      expect(custom['minimumEvidenceCount'], 1);
      expect(custom['requiredEvidenceType'], 'IMAGE');
      expect(custom.containsKey('requestedImageCount'), false);
    },
  );
}
