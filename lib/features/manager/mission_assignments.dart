import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class MissionAssignments extends ConsumerWidget {
  const MissionAssignments({
    super.key,
    required this.mission,
    required this.id,
    required this.reload,
  });

  final Json mission;
  final String id;
  final VoidCallback reload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final path = '/api/missions/${segment(id)}';
    final planning = mission['status'] == 'PLANNING';
    final canReplace = [
      'PENDING_CONFIRMATION',
      'READY',
    ].contains(mission['status']);
    Future<void> replace(Json assignment, {required bool device}) async {
      final key = device ? 'deviceId' : 'staffId';
      final group = device ? 'deviceAssignments' : 'staffAssignments';
      final assignmentId = assignment[device ? 'id' : 'staffId'];
      if (assignmentId == null) return;
      final current = records(mission[group]);
      final excluded = current
          .where(
            (row) =>
                device ||
                current.any(
                  (target) =>
                      target['staffId'] == assignmentId &&
                      target['assignedRole'] == row['assignedRole'],
                ),
          )
          .map((row) => row[key])
          .toSet();
      final body = await editRecord(
        context,
        title: context.tr('Replace resource', 'Thay thế nguồn lực'),
        fields: [
          FieldSpec(
            key,
            'Replacement',
            'Thay thế',
            kind: FieldKind.choice,
            loadOptions: () async {
              final candidates = records(
                await api.request(
                  device ? '/api/drones/available' : '/api/operators/available',
                  query: {'missionId': id},
                ),
              );
              return {
                for (final candidate in candidates)
                  if (candidate['id'] != null &&
                      !excluded.contains(candidate['id']))
                    '${candidate['id']}':
                        '${candidate['fullName'] ?? candidate['name'] ?? candidate['code'] ?? candidate['id']}',
              };
            },
          ),
          const FieldSpec(
            'reason',
            'Reason',
            'Lý do',
            kind: FieldKind.multiline,
          ),
        ],
      );
      if (body == null || !context.mounted) return;
      final collection = device ? 'device-assignments' : 'staff-assignments';
      if (await runAction(
        context,
        () => api.request(
          '$path/$collection/${segment('$assignmentId')}/resource',
          method: 'PUT',
          body: body,
        ),
      )) {
        reload();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final assignment in records(mission['staffAssignments']))
          Card(
            child: ListTile(
              title: Text('${assignment['staffName']}'),
              subtitle: Text(
                '${assignment['assignedRole']} · ${assignment['responseStatus']}',
              ),
              onTap: canReplace && assignment['responseStatus'] == 'REJECTED'
                  ? () => replace(assignment, device: false)
                  : null,
              trailing: planning
                  ? IconButton(
                      tooltip: context.tr('Remove assignment', 'Gỡ phân công'),
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: () async {
                        if (await runAction(
                          context,
                          () => api.request(
                            '$path/staff-assignments/${segment('${assignment['id']}')}',
                            method: 'DELETE',
                          ),
                        )) {
                          reload();
                        }
                      },
                    )
                  : null,
            ),
          ),
        for (final assignment in records(mission['deviceAssignments']))
          Card(
            child: ListTile(
              title: Text(
                '${assignment['deviceName'] ?? assignment['deviceCode']}',
              ),
              subtitle: Text(
                '${assignment['deviceRole']} · ${assignment['status']}',
              ),
              onTap:
                  canReplace &&
                      assignment['replacementRequestedAt'] != null &&
                      assignment['replacementCompleted'] != true
                  ? () => replace(assignment, device: true)
                  : null,
              trailing:
                  canReplace &&
                      assignment['id'] != null &&
                      assignment['replacementRequestedAt'] != null &&
                      assignment['replacementCompleted'] != true
                  ? IconButton(
                      tooltip: context.tr(
                        'Cancel replacement request',
                        'Hủy yêu cầu thay thiết bị',
                      ),
                      icon: const Icon(Icons.cancel_outlined),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialog) => AlertDialog(
                            title: Text(
                              context.tr(
                                'Cancel this replacement request?',
                                'Hủy yêu cầu thay thiết bị này?',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialog, false),
                                child: Text(context.tr('Back', 'Quay lại')),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(dialog, true),
                                child: Text(
                                  context.tr('Cancel request', 'Hủy yêu cầu'),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !context.mounted) return;
                        if (await runAction(
                          context,
                          () => api.request(
                            '$path/device-replacement-requests/${segment('${assignment['id']}')}',
                            method: 'DELETE',
                          ),
                        )) {
                          reload();
                        }
                      },
                    )
                  : planning
                  ? IconButton(
                      tooltip: context.tr('Remove assignment', 'Gỡ phân công'),
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () async {
                        if (await runAction(
                          context,
                          () => api.request(
                            '$path/device-assignments/${segment('${assignment['id']}')}',
                            method: 'DELETE',
                          ),
                        )) {
                          reload();
                        }
                      },
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}
