import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models.dart';
import '../core/settings.dart';
import '../features/auth/session.dart';
import 'strings.dart';

class PortalScaffold extends ConsumerWidget {
  const PortalScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });
  final PreferredSizeWidget? appBar;
  final Widget? body, floatingActionButton;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    if (user == null) {
      return Scaffold(
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
      );
    }
    final bar = appBar is AppBar ? appBar as AppBar : null;
    final destinations = switch (user.role) {
      AppRole.customer => [
        ('/customer/orders', Icons.assignment_outlined, 'Orders', 'Đơn hàng'),
        ('/customer/live', Icons.radar, 'Monitoring', 'Giám sát'),
        ('/customer/media', Icons.photo_library_outlined, 'Media', 'Dữ liệu'),
        ('/notifications', Icons.notifications_none, 'Alerts', 'Thông báo'),
        ('/home', Icons.grid_view_outlined, 'More', 'Thêm'),
      ],
      AppRole.manager => [
        (
          '/manager/dashboard',
          Icons.dashboard_outlined,
          'Overview',
          'Tổng quan',
        ),
        ('/manager/orders', Icons.assignment_outlined, 'Orders', 'Đơn hàng'),
        ('/manager/missions', Icons.work_outline, 'Missions', 'Nhiệm vụ'),
        (
          '/manager/schedule',
          Icons.calendar_month_outlined,
          'Schedule',
          'Lịch',
        ),
        ('/home', Icons.grid_view_outlined, 'More', 'Thêm'),
      ],
      AppRole.staff => [
        (
          '/staff/missions',
          Icons.assignment_ind_outlined,
          'Missions',
          'Nhiệm vụ',
        ),
        (
          '/staff/availability',
          Icons.calendar_month_outlined,
          'Availability',
          'Lịch bận',
        ),
        ('/staff/maintenance', Icons.build_outlined, 'Maintenance', 'Bảo trì'),
        ('/notifications', Icons.notifications_none, 'Alerts', 'Thông báo'),
        ('/home', Icons.grid_view_outlined, 'More', 'Thêm'),
      ],
    };
    String path;
    try {
      path = GoRouterState.of(context).uri.path;
    } catch (_) {
      path = '/home';
    }
    var selected = destinations.indexWhere(
      (entry) => path == entry.$1 || path.startsWith('${entry.$1}/'),
    );
    if (selected < 0) selected = destinations.length - 1;
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: bar?.title ?? const Text('ODMS'),
        leading:
            bar?.leading ??
            (Navigator.of(context).canPop()
                ? null
                : Padding(
                    padding: const EdgeInsets.all(13),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  )),
        automaticallyImplyLeading: bar?.automaticallyImplyLeading ?? true,
        actions: [
          ...?bar?.actions,
          PopupMenuButton<String>(
            tooltip: context.tr('Account and settings', 'Tài khoản và cài đặt'),
            position: PopupMenuPosition.under,
            onSelected: (value) {
              if (value == 'profile') context.push('/profile');
              if (value == 'language') {
                ref.read(localeProvider.notifier).toggle();
              }
              if (value == 'theme') {
                ref.read(themeModeProvider.notifier).toggle();
              }
              if (value == 'support') context.push('/support');
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Text(context.tr('My profile', 'Hồ sơ của tôi')),
              ),
              PopupMenuItem(
                value: 'language',
                child: Text(context.tr('Tiếng Việt', 'English')),
              ),
              PopupMenuItem(
                value: 'theme',
                child: Text(context.tr('Switch theme', 'Đổi sáng / tối')),
              ),
              PopupMenuItem(
                value: 'support',
                child: Text(context.tr('Support', 'Hỗ trợ')),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  user.fullName.trim().isEmpty
                      ? '?'
                      : user.fullName
                            .trim()
                            .split(RegExp(r'\s+'))
                            .map((s) => s.characters.first)
                            .take(2)
                            .join(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: bar?.bottom,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (index) => context.go(destinations[index].$1),
          destinations: [
            for (final entry in destinations)
              NavigationDestination(
                icon: Icon(entry.$2, size: 22),
                label: context.tr(entry.$3, entry.$4),
              ),
          ],
        ),
      ),
    );
  }
}
