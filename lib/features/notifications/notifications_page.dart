import '../../shared/portal_scaffold.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../auth/session.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        role = ref.watch(sessionProvider).user!.role;
    return PortalScaffold(
      appBar: AppBar(title: Text(context.tr('Notifications', 'Thông báo'))),
      body: RemoteView(
        load: () => api.request('/api/notifications', query: {'limit': 30}),
        builder: (context, data, reload) => RecordList(
          items: records(data),
          refresh: reload,
          onTap: (item) {
            final type = '${item['type']}', id = segment('${item['entityId']}');
            if (type.startsWith('ORDER_') && role != AppRole.staff) {
              context.push('/${role.name}/orders/$id');
            }
            if (type.startsWith('MISSION_') && role != AppRole.customer) {
              context.push('/${role.name}/missions/$id');
            }
          },
        ),
      ),
    );
  }
}
