import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../auth/session.dart';
import '../manager/mission_workspace.dart';
import '../staff/mission_workspace.dart';

class MissionDetailPage extends ConsumerWidget {
  const MissionDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        manager = ref.watch(sessionProvider).user!.role == AppRole.manager,
        path = '/api/missions/${segment(id)}';
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Mission details', 'Chi tiết nhiệm vụ')),
      ),
      body: RemoteView(
        load: () async => {
          'mission': await api.request(path),
          'permissions': await api.request('$path/permissions'),
        },
        builder: (context, value, reload) {
          final mission = object(object(value)['mission']),
              permissions = object(object(value)['permissions']);

          if (manager) {
            return ManagerMissionWorkspace(
              mission: mission,
              permissions: permissions,
              id: id,
              reload: reload,
            );
          }
          return StaffMissionWorkspace(
            mission: mission,
            permissions: permissions,
            id: id,
          );
        },
      ),
    );
  }
}
