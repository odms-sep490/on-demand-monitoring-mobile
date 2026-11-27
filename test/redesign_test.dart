import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:odms_mobile/app/theme.dart';
import 'package:odms_mobile/core/api_client.dart';
import 'package:odms_mobile/core/models.dart';
import 'package:odms_mobile/core/providers.dart';
import 'package:odms_mobile/features/auth/session.dart';
import 'package:odms_mobile/features/customer/orders_page.dart';
import 'package:odms_mobile/features/manager/dashboard_page.dart';
import 'package:odms_mobile/features/staff/missions_page.dart';

import 'api_client_test.dart' show FakeAdapter, MemorySecrets, response;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('EXPORT_PREVIEWS')) return;
    final font = FontLoader('BeVietnamPro')
      ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Regular.ttf'));
    await font.load();
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes().then((data) => ByteData.view(data.buffer)),
        );
      await icons.load();
    }
  });
  for (final brightness in Brightness.values) {
    for (final role in AppRole.values) {
      testWidgets(
        'redesigned ${role.name} page retains website content at 360px (${brightness.name})',
        (tester) async {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
          dio.httpClientAdapter = FakeAdapter((options) async {
            return response(switch (options.path) {
              '/api/orders/mine' => [
                {
                  'id': 'o1',
                  'orderCode': 'ORD-2026-001',
                  'title': 'Giám sát công trình',
                  'serviceName': 'Kiểm tra nhà xưởng',
                  'address': 'Thành phố Hồ Chí Minh',
                  'orderStatus': 'PENDING',
                  'preferredDateFrom': '2026-11-22',
                  'preferredTimeName': 'Buổi sáng',
                },
                {
                  'id': 'o2',
                  'title': 'Kiểm tra mái nhà',
                  'orderCode': 'ORD-2026-002',
                  'orderStatus': 'COMPLETED',
                },
              ],
              '/api/manager/dashboard' => {
                'summary': {
                  'pendingOrderCount': 5,
                  'waitingDepositCount': 3,
                  'activeMissionCount': 4,
                  'totalOrders': 24,
                  'attentionRequiredCount': 2,
                },
                'pricingPipeline': {
                  'pricingReviewCount': 2,
                  'quoteReadyCount': 3,
                  'waitingCustomerCount': 4,
                  'waitingDepositCount': 3,
                  'depositPaidCount': 12,
                },
                'missionOverview': {
                  'scheduledCount': 6,
                  'readyCount': 2,
                  'inFlightCount': 1,
                  'returningCount': 0,
                  'completedTodayCount': 3,
                  'issueCount': 2,
                },
                'actionItems': [
                  {
                    'id': 'a1',
                    'title': 'Đơn hàng cần duyệt',
                    'description': 'Yêu cầu giám sát công trình mới',
                    'orderId': 'o1',
                  },
                ],
                'orderStatusDistribution': [
                  {'key': 'APPROVED', 'count': 12},
                  {'key': 'COMPLETED', 'count': 7},
                ],
                'recentOrders': [],
                'missionTrend': [],
                'recentActivities': [],
                'serviceDistribution': [],
                'missionStatusDistribution': [],
              },
              '/api/missions/mine' => [
                {
                  'id': 'm1',
                  'missionCode': 'MS-2026-001',
                  'orderTitle': 'Giám sát công trình',
                  'status': 'PENDING_CONFIRMATION',
                  'orderStatus': 'APPROVED',
                  'serviceName': 'Kiểm tra nhà xưởng',
                  'address': 'Thành phố Hồ Chí Minh',
                  'scheduledStartAt': '2026-11-22T02:00:00Z',
                },
              ],
              '/api/missions/m1/permissions' => {'canRespond': true},
              '/api/staff-licenses/users/user' => [
                {
                  'licenseStatus': 'ACTIVE',
                  'verificationStatus': 'VERIFIED',
                  'expiryDate': null,
                },
              ],
              _ => [],
            });
          });
          final api = ApiClient(
            'https://api.example',
            MemorySecrets(),
            transport: dio,
          );
          final session = SessionController(api)
            ..user = AppUser(
              id: 'user',
              email: 'preview@example.com',
              fullName: 'Nguyễn Minh Anh',
              role: role,
            )
            ..status = SessionStatus.authenticated;
          final boundaryKey = GlobalKey();
          final page = switch (role) {
            AppRole.customer => const CustomerOrdersPage(),
            AppRole.manager => const ManagerDashboardPage(),
            AppRole.staff => const StaffMissionsPage(),
          };
          final path = switch (role) {
            AppRole.customer => '/customer/orders',
            AppRole.manager => '/manager/dashboard',
            AppRole.staff => '/staff/missions',
          };
          final router = GoRouter(
            initialLocation: path,
            routes: [GoRoute(path: path, builder: (_, _) => page)],
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                apiProvider.overrideWithValue(api),
                sessionProvider.overrideWithValue(session),
              ],
              child: RepaintBoundary(
                key: boundaryKey,
                child: MaterialApp.router(
                  debugShowCheckedModeBanner: false,
                  theme: odmsTheme(brightness: brightness),
                  locale: const Locale('vi'),
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  supportedLocales: const [Locale('vi'), Locale('en')],
                  routerConfig: router,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/images/logo.png'),
              boundaryKey.currentContext!,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (role == AppRole.customer) {
            expect(find.text('Đơn gần nhất'), findsOneWidget);
            expect(find.text('Tạo yêu cầu'), findsOneWidget);
          }
          if (role == AppRole.manager) {
            expect(find.text('Duyệt đơn hàng'), findsOneWidget);
          }
          if (role == AppRole.staff) {
            expect(find.text('Nhiệm vụ được giao'), findsOneWidget);
            expect(find.text('Chờ phản hồi'), findsWidgets);
            expect(find.text('Điều khiển bay'), findsNothing);
          }
          if (const bool.fromEnvironment('EXPORT_PREVIEWS')) {
            await tester.runAsync(() async {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              Directory('build/previews').createSync(recursive: true);
              File(
                'build/previews/${role.name}${brightness == Brightness.dark ? '-dark' : ''}-redesign.png',
              ).writeAsBytesSync(png!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (role == AppRole.customer) {
            await tester.enterText(find.byType(TextField).last, 'not-found');
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('Chưa có đơn hàng phù hợp.'),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            expect(find.text('Chưa có đơn hàng phù hợp.'), findsOneWidget);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
          session.dispose();
          dio.close();
        },
      );
    }
  }
}
