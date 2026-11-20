import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config.dart';
import '../core/models.dart';
import '../core/mobile_policy.dart';
import '../features/auth/auth_page.dart';
import '../features/auth/session.dart';
import '../features/profile/profile_page.dart';
import '../shared/strings.dart';
import 'routes.dart';
import 'theme.dart';

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  @override
  Locale build() => const Locale('vi');
  void toggle() => state = Locale(state.languageCode == 'vi' ? 'en' : 'vi');
}

class OdmsApp extends ConsumerStatefulWidget {
  const OdmsApp({super.key});
  @override
  ConsumerState<OdmsApp> createState() => _OdmsAppState();
}

class _OdmsAppState extends ConsumerState<OdmsApp> {
  late final session = ref.read(sessionProvider);
  late final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: session,
    redirect: (context, state) {
      if (session.status == SessionStatus.loading ||
          session.status == SessionStatus.unavailable) {
        return state.uri.path == '/loading' ? null : '/loading';
      }
      if (session.status != SessionStatus.authenticated) {
        return state.uri.path == '/auth' ? null : '/auth';
      }
      if (state.uri.path == '/auth' || state.uri.path == '/loading') {
        return '/home';
      }
      if (!mayOpenMobilePath(session.user!.role, state.uri.path)) {
        return '/home';
      }
      final role = session.user!.role.name;
      for (final prefix in ['customer', 'manager', 'staff']) {
        if (state.uri.path.startsWith('/$prefix/') && prefix != role) {
          return '/home';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, _) => const AuthPage()),
      GoRoute(
        path: '/loading',
        builder: (_, _) => ListenableBuilder(
          listenable: session,
          builder: (context, _) => Scaffold(
            body: Center(
              child: session.status == SessionStatus.unavailable
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            session.error ??
                                context.tr(
                                  'Cannot restore session.',
                                  'Chưa thể khôi phục phiên.',
                                ),
                          ),
                        ),
                        FilledButton(
                          onPressed: session.restore,
                          child: Text(context.tr('Retry', 'Thử lại')),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (_, _) => HomePage(key: ValueKey(session.revision)),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => ProfilePage(key: ValueKey(session.revision)),
      ),
      ...featureRoutes(),
    ],
  );
  @override
  void initState() {
    super.initState();
    if (AppConfig.validate() == null) session.restore();
  }

  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configurationError = AppConfig.validate();
    if (configurationError != null) {
      return MaterialApp(
        theme: odmsTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(configurationError),
            ),
          ),
        ),
      );
    }
    return MaterialApp.router(
      title: 'ODMS Mobile',
      debugShowCheckedModeBanner: false,
      theme: odmsTheme(),
      locale: ref.watch(localeProvider),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('vi'), Locale('en')],
      routerConfig: router,
    );
  }
}

class MenuEntry {
  const MenuEntry(this.path, this.en, this.vi, this.icon, this.roles);
  final String path, en, vi;
  final IconData icon;
  final Set<AppRole> roles;
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user!;
    final entries = menuEntries()
        .where((entry) => entry.roles.contains(user.role))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('ODMS'),
        actions: [
          IconButton(
            tooltip: context.tr('Language', 'Ngôn ngữ'),
            onPressed: () => ref.read(localeProvider.notifier).toggle(),
            icon: const Icon(Icons.translate),
          ),
          IconButton(
            tooltip: context.tr('Profile', 'Hồ sơ'),
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    'Your monitoring workspace',
                    'Không gian giám sát của bạn',
                  ),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  user.fullName,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(switch (user.role) {
                  AppRole.customer => context.tr('Customer', 'Khách hàng'),
                  AppRole.staff => context.tr('Staff', 'Nhân viên'),
                  AppRole.manager => context.tr('Manager', 'Quản lý'),
                }, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          for (final entry in entries)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(
                  entry.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(context.tr(entry.en, entry.vi)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(entry.path),
              ),
            ),
        ],
      ),
    );
  }
}
