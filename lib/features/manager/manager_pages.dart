import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/record_lookup.dart';
import '../../shared/editor.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

export 'dashboard_page.dart';

class ManagerOrdersPage extends ConsumerWidget {
  const ManagerOrdersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PortalScaffold(
    appBar: AppBar(
      title: Text(context.tr('Order queue', 'Danh sách đơn hàng')),
    ),
    body: RemoteView(
      load: () => ref.read(apiProvider).request('/api/orders/managed'),
      builder: (context, data, reload) => RecordList(
        items: records(data),
        refresh: reload,
        onTap: (item) async {
          await context.push('/manager/orders/${segment('${item['id']}')}');
          reload();
        },
      ),
    ),
  );
}

class MissionsPage extends ConsumerWidget {
  const MissionsPage({super.key, this.staff = false, this.schedule = false});
  final bool staff, schedule;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return PortalScaffold(
      appBar: AppBar(
        title: Text(
          schedule
              ? context.tr('Schedule', 'Lịch nhiệm vụ')
              : context.tr('Missions', 'Nhiệm vụ'),
        ),
      ),
      body: RemoteView(
        load: () =>
            api.request(staff ? '/api/missions/mine' : '/api/missions/all'),
        builder: (context, data, reload) {
          final items = records(data);
          if (schedule) {
            items.sort(
              (a, b) => '${a['scheduledStartAt']}'.compareTo(
                '${b['scheduledStartAt']}',
              ),
            );
          }
          return RecordList(
            items: items,
            refresh: reload,
            onTap: (item) async {
              await context.push(
                '/${staff ? 'staff' : 'manager'}/missions/${segment('${item['id']}')}',
              );
              reload();
            },
          );
        },
      ),
      floatingActionButton: staff
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await createMission(context, api);
              },
              icon: const Icon(Icons.add),
              label: Text(context.tr('Create mission', 'Tạo nhiệm vụ')),
            ),
    );
  }
}

Future<bool> createMission(
  BuildContext context,
  ApiClient api, {
  String? orderId,
}) async {
  try {
    return await _createMission(context, api, orderId: orderId);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
    return false;
  }
}

Future<bool> _createMission(
  BuildContext context,
  ApiClient api, {
  String? orderId,
}) async {
  final selection = orderId != null
      ? {'orderId': orderId}
      : await editRecord(
          context,
          title: context.tr('Choose approved order', 'Chọn đơn đã duyệt'),
          fields: [
            FieldSpec(
              'orderId',
              'Order',
              'Đơn hàng',
              kind: FieldKind.choice,
              loadOptions: () =>
                  lookup(api, '/api/orders/approved', label: 'title'),
            ),
          ],
        );
  if (selection == null || !context.mounted) return false;
  final id = segment('${selection['orderId']}');
  final order = object(await api.request('/api/orders/$id'));
  final plan = object(await api.request('/api/orders/$id/execution-plan'));
  final additional = plan['planStatus'] == 'FINALIZED';
  if (!context.mounted) return false;
  final body = await editRecord(
    context,
    title: context.tr('Create mission', 'Tạo nhiệm vụ'),
    fields: [
      const FieldSpec('scopeLabel', 'Mission scope', 'Phạm vi nhiệm vụ'),
      const FieldSpec(
        'scheduledStartAt',
        'Start (device time zone)',
        'Bắt đầu (múi giờ thiết bị)',
        kind: FieldKind.instant,
      ),
      const FieldSpec(
        'scheduledEndAt',
        'End (device time zone)',
        'Kết thúc (múi giờ thiết bị)',
        kind: FieldKind.instant,
      ),
      FieldSpec(
        'checklistIds',
        'Checklist items',
        'Hạng mục giám sát',
        kind: FieldKind.multiChoice,
        options: {
          for (final item in records(order['checklistItems']))
            '${item['id']}': '${item['content']}',
        },
      ),
    ],
    validate: (data) =>
        '${data['scheduledStartAt']}'.compareTo('${data['scheduledEndAt']}') >=
            0
        ? context.tr('End must follow start.', 'Kết thúc phải sau bắt đầu.')
        : null,
  );
  if (body == null || !context.mounted) return false;
  return runAction(
    context,
    () => api.request(
      '/api/missions/$id${additional ? '/additional' : ''}',
      method: 'POST',
      body: body,
    ),
  );
}

class ExecutionPlanPage extends ConsumerWidget {
  const ExecutionPlanPage({
    super.key,
    required this.orderId,
    this.reworkCaseId,
  });
  final String orderId;
  final String? reworkCaseId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        path = '/api/orders/${segment(orderId)}/execution-plan';
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Execution plan', 'Kế hoạch thực hiện')),
      ),
      body: RemoteView(
        load: () => api.request(path),
        builder: (context, data, reload) {
          final plan = object(data);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DetailFields(
                data: plan,
                fields: const {
                  'planStatus': ('Plan status', 'Trạng thái kế hoạch'),
                  'revision': ('Revision', 'Phiên bản'),
                  'blockers': ('Needs resolution', 'Cần giải quyết'),
                },
              ),
              DetailFields(
                data: object(plan['coverage']),
                fields: const {
                  'total': ('Requirements', 'Yêu cầu'),
                  'covered': ('Assigned', 'Đã phân bổ'),
                  'uncovered': ('Unassigned', 'Chưa phân bổ'),
                  'repeated': ('Repeated', 'Lặp lại'),
                },
              ),
              for (final item in records(plan['missions']))
                Card(
                  child: ListTile(
                    title: Text('${item['scopeLabel']}'),
                    subtitle: Text('${item['assignmentCount']}'),
                    onTap: () => context.push(
                      '/manager/missions/${segment('${item['missionId']}')}',
                    ),
                  ),
                ),
              if (plan['planStatus'] == 'DRAFT' &&
                  object(plan['coverage'])['coverageReady'] == true)
                FilledButton(
                  onPressed: () async {
                    final confirmation = await editRecord(
                      context,
                      title: context.tr('Finalize plan', 'Chốt kế hoạch'),
                      fields: const [
                        FieldSpec(
                          'decompositionConfirmed',
                          'I confirm the mission coverage and division of work',
                          'Tôi xác nhận phạm vi và phân chia công việc',
                          kind: FieldKind.toggle,
                        ),
                      ],
                    );
                    if (confirmation != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            reworkCaseId == null
                                ? '$path/finalize'
                                : '/api/manager/result-revision-cases/${segment(reworkCaseId!)}/rework-plan/finalize',
                            method: 'POST',
                            body: {
                              ...confirmation,
                              'expectedPlanRevision': plan['revision'],
                            },
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(context.tr('Finalize plan', 'Chốt kế hoạch')),
                ),
              if (plan['planStatus'] == 'FINALIZED' && reworkCaseId == null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(context.tr('Add mission', 'Thêm nhiệm vụ')),
                  onPressed: () async {
                    if (await createMission(context, api, orderId: orderId) &&
                        context.mounted) {
                      reload();
                    }
                  },
                ),
              if (plan['planStatus'] == 'FINALIZED')
                OutlinedButton(
                  onPressed: () async {
                    final reason = await editRecord(
                      context,
                      title: context.tr('Amend plan', 'Điều chỉnh kế hoạch'),
                      fields: const [
                        FieldSpec(
                          'reason',
                          'Reason',
                          'Lý do',
                          kind: FieldKind.multiline,
                        ),
                      ],
                    );
                    if (reason != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            '$path/amend',
                            method: 'POST',
                            body: {
                              ...reason,
                              'expectedPlanRevision': plan['revision'],
                            },
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(context.tr('Amend plan', 'Điều chỉnh kế hoạch')),
                ),
            ],
          );
        },
      ),
    );
  }
}
