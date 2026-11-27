import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/record_lookup.dart';
import '../../shared/editor.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class MissionResourceOptions extends ConsumerWidget {
  const MissionResourceOptions({
    super.key,
    required this.id,
    required this.mission,
    required this.reload,
  });

  final String id;
  final Json mission;
  final VoidCallback reload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final path = '/api/missions/${segment(id)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final estimate in [true, false])
          OutlinedButton(
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => PortalScaffold(
                    appBar: AppBar(
                      title: Text(
                        estimate
                            ? context.tr(
                                'Resource estimate',
                                'Ước tính nguồn lực',
                              )
                            : context.tr(
                                'Resource recommendations',
                                'Đề xuất nguồn lực',
                              ),
                      ),
                    ),
                    body: RemoteView(
                      load: () => api.request(
                        estimate
                            ? '/api/manager/missions/${segment(id)}/ai/resource-estimate'
                            : '$path/recommendations',
                        method: 'POST',
                      ),
                      builder: (context, data, reload) {
                        final result = object(data);
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (estimate) ...[
                              DetailFields(
                                data: result,
                                fields: const {
                                  'summary': ('Summary', 'Tóm tắt'),
                                  'estimatedStaffCount': ('Staff', 'Nhân sự'),
                                  'estimatedDeviceCount': (
                                    'Devices',
                                    'Thiết bị',
                                  ),
                                  'assumptions': ('Assumptions', 'Giả định'),
                                },
                              ),
                              for (final row in [
                                ...records(result['staffByRole']),
                                ...records(result['devicesByType']),
                              ])
                                ListTile(
                                  title: Text(
                                    "${row['role'] ?? row['deviceTypeCode']} · ${row['count']}",
                                  ),
                                  subtitle: Text("${row['reason'] ?? ''}"),
                                ),
                            ] else ...[
                              DetailFields(
                                data: object(result['aiEstimation']),
                                fields: const {
                                  'reason': ('Reason', 'Lý do'),
                                  'recommendedDevices': (
                                    'Recommended devices',
                                    'Thiết bị đề xuất',
                                  ),
                                  'warnings': ('Warnings', 'Cảnh báo'),
                                },
                              ),
                              if (records(result['recommendations']).isEmpty)
                                Text(
                                  context.tr(
                                    'No recommendation available.',
                                    'Chưa có đề xuất.',
                                  ),
                                ),
                              for (final row in records(
                                result['recommendations'],
                              ))
                                Card(
                                  child: ExpansionTile(
                                    title: Text(
                                      "${row['date']} · ${row['riskLevel']}",
                                    ),
                                    children: [
                                      DetailFields(
                                        data: row,
                                        fields: const {
                                          'availableStaffCount': (
                                            'Available staff',
                                            'Nhân sự khả dụng',
                                          ),
                                          'availableDeviceCount': (
                                            'Available devices',
                                            'Thiết bị khả dụng',
                                          ),
                                          'deviceShortageCount': (
                                            'Device shortage',
                                            'Thiếu thiết bị',
                                          ),
                                          'staffShortageCount': (
                                            'Staff shortage',
                                            'Thiếu nhân sự',
                                          ),
                                          'warnings': ('Warnings', 'Cảnh báo'),
                                        },
                                      ),
                                      for (final candidate in records(
                                        row['deviceCandidates'],
                                      ))
                                        ListTile(
                                          trailing:
                                              candidate['id'] == null ||
                                                  records(
                                                    mission['deviceAssignments'],
                                                  ).any(
                                                    (row) =>
                                                        row['deviceId'] ==
                                                        candidate['id'],
                                                  )
                                              ? null
                                              : IconButton(
                                                  tooltip: context.tr(
                                                    'Assign device',
                                                    'Phân công thiết bị',
                                                  ),
                                                  icon: const Icon(
                                                    Icons.add_circle_outline,
                                                  ),
                                                  onPressed: () async {
                                                    final available =
                                                        await runAction(context, () async {
                                                          final options =
                                                              await lookup(
                                                                api,
                                                                '/api/drones/available',
                                                                query: {
                                                                  'missionId':
                                                                      id,
                                                                },
                                                              );
                                                          if (!options.containsKey(
                                                            '${candidate['id']}',
                                                          )) {
                                                            throw StateError(
                                                              'Device is unavailable for the current mission schedule.',
                                                            );
                                                          }
                                                          return null;
                                                        });
                                                    if (!available ||
                                                        !context.mounted) {
                                                      return;
                                                    }
                                                    final body = await editRecord(
                                                      context,
                                                      title: context.tr(
                                                        'Assign for the current mission schedule',
                                                        'Gán theo lịch hiện tại của nhiệm vụ',
                                                      ),
                                                      fields: const [
                                                        FieldSpec(
                                                          'deviceRole',
                                                          'Device role',
                                                          'Vai trò thiết bị',
                                                          kind:
                                                              FieldKind.choice,
                                                          options: {
                                                            'MAIN':
                                                                'Main / Chính',
                                                            'SUPPORT': 'Support / Hỗ trợ',
                                                          },
                                                        ),
                                                      ],
                                                    );
                                                    if (body == null ||
                                                        !context.mounted) {
                                                      return;
                                                    }
                                                    if (await runAction(
                                                          context,
                                                          () => api.request(
                                                            '$path/device-assignments',
                                                            method: 'POST',
                                                            body: {
                                                              ...body,
                                                              'deviceId':
                                                                  candidate['id'],
                                                            },
                                                          ),
                                                        ) &&
                                                        context.mounted) {
                                                      Navigator.of(context)
                                                          .pop();
                                                    }
                                                  },
                                                ),
                                          title: Text(
                                            "${candidate['code']} · ${candidate['name']}",
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
              if (context.mounted) reload();
            },
            child: Text(
              estimate
                  ? context.tr('Estimate resources', 'Ước tính nguồn lực')
                  : context.tr('Suggest resources', 'Đề xuất nguồn lực'),
            ),
          ),
      ],
    );
  }
}
