import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../features/customer/customer_pages.dart';
import '../features/customer/media_page.dart';
import 'app.dart';

List<RouteBase> featureRoutes() => [
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
