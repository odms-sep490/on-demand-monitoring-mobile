import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/record_lookup.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class MissionPlanningControls extends ConsumerWidget {
  const MissionPlanningControls({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonal(
          onPressed: () async {
            final body = await editRecord(
              context,
              title: context.tr('Assign staff', 'Phân công nhân viên'),
              fields: [
                FieldSpec(
                  'staffId',
                  'Staff member',
                  'Nhân viên',
                  kind: FieldKind.choice,
                  loadOptions: () => lookup(
                    api,
                    '/api/operators/available',
                    query: {'missionId': id},
                    label: 'fullName',
                  ),
                ),
                const FieldSpec(
                  'assignedRoles',
                  'Roles',
                  'Vai trò',
                  kind: FieldKind.multiChoice,
                  options: {
                    'PILOT': 'Pilot / Phi công',
                    'OPERATOR': 'Operator / Vận hành',
                    'MAINTAINER': 'Maintainer / Bảo trì',
                    'INSPECTOR': 'Inspector / Kiểm tra',
                  },
                ),
              ],
            );
            if (body != null &&
                context.mounted &&
                await runAction(
                  context,
                  () => api.request(
                    '$path/staff-assignments',
                    method: 'POST',
                    body: body,
                  ),
                )) {
              reload();
            }
          },
          child: Text(context.tr('Assign staff', 'Phân công nhân viên')),
        ),
        FilledButton.tonal(
          onPressed: () async {
            final body = await editRecord(
              context,
              title: context.tr('Assign device', 'Phân công thiết bị'),
              fields: [
                FieldSpec(
                  'deviceId',
                  'Device',
                  'Thiết bị',
                  kind: FieldKind.choice,
                  loadOptions: () => lookup(
                    api,
                    '/api/drones/available',
                    query: {'missionId': id},
                  ),
                ),
                const FieldSpec(
                  'deviceRole',
                  'Device role',
                  'Vai trò thiết bị',
                  kind: FieldKind.choice,
                  options: {
                    'MAIN': 'Main / Chính',
                    'SUPPORT': 'Support / Hỗ trợ',
                  },
                ),
              ],
            );
            if (body != null &&
                context.mounted &&
                await runAction(
                  context,
                  () => api.request(
                    '$path/device-assignments',
                    method: 'POST',
                    body: body,
                  ),
                )) {
              reload();
            }
          },
          child: Text(context.tr('Assign device', 'Phân công thiết bị')),
        ),
        FilledButton(
          onPressed: () async {
            if (await runAction(
              context,
              () => api.request('$path/confirm-planning', method: 'POST'),
            )) {
              reload();
            }
          },
          child: Text(
            context.tr(
              'Confirm mission planning',
              'Xác nhận kế hoạch nhiệm vụ',
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () async {
            final plan = object(
              await api.request(
                '/api/orders/${segment('${mission['orderId']}')}/execution-plan',
              ),
            );
            final order = object(
              await api.request(
                '/api/orders/${segment('${mission['orderId']}')}',
              ),
            );
            final assignment = object(
              await api.request('$path/checklist-assignments'),
            );
            if (!context.mounted) return;
            final body = await editRecord(
              context,
              title: context.tr('Allocate checklist', 'Phân bổ hạng mục'),
              fields: [
                FieldSpec(
                  'ids',
                  'Requirements',
                  'Yêu cầu',
                  kind: FieldKind.multiChoice,
                  initial: records(assignment['assignments'])
                      .where((e) => e['active'] == true)
                      .map((e) => '${e['orderChecklistItemId']}')
                      .toList(),
                  options: {
                    for (final item in records(order['checklistItems']))
                      '${item['id']}': '${item['content']}',
                  },
                ),
              ],
            );
            if (body != null &&
                context.mounted &&
                await runAction(
                  context,
                  () => api.request(
                    '$path/checklist-assignments',
                    method: 'PUT',
                    body: {
                      'expectedPlanRevision': plan['revision'],
                      'items': (body['ids'] as List)
                          .map((e) => {'orderChecklistItemId': e})
                          .toList(),
                    },
                  ),
                )) {
              reload();
            }
          },
          child: Text(context.tr('Allocate checklist', 'Phân bổ hạng mục')),
        ),
      ],
    );
  }
}
