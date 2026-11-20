import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../features/customer/customer_pages.dart';
import '../features/customer/media_page.dart';
import '../features/support/support_pages.dart';
import '../features/notifications/notifications_page.dart';
import '../features/manager/manager_pages.dart';
import '../features/missions/mission_detail.dart';
import '../features/devices/device_pages.dart';
import '../features/customer/order_detail.dart';
import '../features/maintenance/maintenance_page.dart';
import '../features/staff/availability_page.dart';
import '../features/staff/checklist_page.dart';
import '../features/staff/evidence_page.dart';
import '../features/staff/licenses_page.dart';
import '../features/customer/live_status_page.dart';
import 'app.dart';

List<RouteBase> featureRoutes() => [
  GoRoute(path: '/customer/live', builder: (_, _) => const LiveStatusPage()),
  GoRoute(path: '/staff/licenses', builder: (_, _) => const LicensesPage()),
  GoRoute(
    path: '/staff/missions',
    builder: (_, _) => const MissionsPage(staff: true),
  ),
  GoRoute(
    path: '/staff/missions/:id',
    builder: (_, state) => MissionDetailPage(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/staff/missions/:id/checklist',
    builder: (_, state) =>
        ChecklistPage(missionId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/staff/missions/:id/media',
    builder: (_, state) => EvidencePage(missionId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/staff/availability',
    builder: (_, _) => const AvailabilityPage(),
  ),
  GoRoute(path: '/staff/devices', builder: (_, _) => const DevicesPage()),
  GoRoute(
    path: '/staff/maintenance',
    builder: (_, _) => const MaintenancePage(),
  ),

  GoRoute(
    path: '/manager/maintenance',
    builder: (_, _) => const MaintenancePage(),
  ),
  GoRoute(
    path: '/manager/dashboard',
    builder: (_, _) => const ManagerDashboardPage(),
  ),
  GoRoute(
    path: '/manager/orders',
    builder: (_, _) => const ManagerOrdersPage(),
  ),
  GoRoute(
    path: '/manager/orders/:id',
    builder: (_, state) =>
        OrderDetailPage(id: state.pathParameters['id']!, manager: true),
  ),
  GoRoute(path: '/manager/missions', builder: (_, _) => const MissionsPage()),
  GoRoute(
    path: '/manager/missions/:id',
    builder: (_, state) => MissionDetailPage(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/manager/schedule',
    builder: (_, _) => const MissionsPage(schedule: true),
  ),
  GoRoute(path: '/manager/devices', builder: (_, _) => const DevicesPage()),

  GoRoute(path: '/support', builder: (_, _) => const SupportPage()),
  GoRoute(path: '/notifications', builder: (_, _) => const NotificationsPage()),
  GoRoute(
    path: '/customer/orders',
    builder: (_, _) => const CustomerOrdersPage(),
  ),
  GoRoute(
    path: '/customer/orders/:id',
    builder: (_, state) => CustomerOrderPage(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/customer/media',
    builder: (_, _) => const CustomerMediaPage(),
  ),
];
List<MenuEntry> menuEntries() => [
  const MenuEntry(
    '/customer/live',
    'Monitoring status',
    'Tình trạng giám sát',
    Icons.radar,
    {AppRole.customer},
  ),
  const MenuEntry(
    '/staff/licenses',
    'My qualifications',
    'Chứng chỉ của tôi',
    Icons.badge_outlined,
    {AppRole.staff},
  ),
  const MenuEntry(
    '/staff/missions',
    'Assigned missions',
    'Nhiệm vụ được giao',
    Icons.assignment_ind_outlined,
    {AppRole.staff},
  ),
  const MenuEntry(
    '/staff/availability',
    'Availability',
    'Lịch bận',
    Icons.calendar_month_outlined,
    {AppRole.staff},
  ),
  const MenuEntry(
    '/staff/devices',
    'Device records',
    'Thông tin thiết bị',
    Icons.precision_manufacturing_outlined,
    {AppRole.staff},
  ),
  const MenuEntry(
    '/staff/maintenance',
    'Maintenance',
    'Bảo trì',
    Icons.build_outlined,
    {AppRole.staff},
  ),

  const MenuEntry(
    '/manager/maintenance',
    'Maintenance',
    'Bảo trì',
    Icons.build_outlined,
    {AppRole.manager},
  ),
  const MenuEntry(
    '/manager/dashboard',
    'Dashboard',
    'Tổng quan',
    Icons.dashboard_outlined,
    {AppRole.manager},
  ),
  const MenuEntry(
    '/manager/orders',
    'Order queue',
    'Danh sách đơn hàng',
    Icons.assignment_outlined,
    {AppRole.manager},
  ),
  const MenuEntry(
    '/manager/missions',
    'Missions',
    'Nhiệm vụ',
    Icons.work_outline,
    {AppRole.manager},
  ),
  const MenuEntry(
    '/manager/schedule',
    'Schedule',
    'Lịch nhiệm vụ',
    Icons.calendar_month_outlined,
    {AppRole.manager},
  ),
  const MenuEntry(
    '/manager/devices',
    'Devices',
    'Thiết bị',
    Icons.precision_manufacturing_outlined,
    {AppRole.manager},
  ),

  const MenuEntry('/support', 'Support', 'Hỗ trợ', Icons.support_agent, {
    AppRole.customer,
    AppRole.manager,
    AppRole.staff,
  }),
  const MenuEntry(
    '/notifications',
    'Notifications',
    'Thông báo',
    Icons.notifications_outlined,
    {AppRole.customer, AppRole.manager, AppRole.staff},
  ),
  const MenuEntry(
    '/customer/orders',
    'My orders',
    'Đơn hàng của tôi',
    Icons.assignment_outlined,
    {AppRole.customer},
  ),
  const MenuEntry(
    '/customer/media',
    'Media library',
    'Thư viện dữ liệu',
    Icons.photo_library_outlined,
    {AppRole.customer},
  ),
];
