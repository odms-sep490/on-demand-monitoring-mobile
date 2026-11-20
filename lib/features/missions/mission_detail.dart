import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../auth/session.dart';
import '../customer/customer_pages.dart' show lookup;
import '../manager/review_page.dart';
import '../manager/manager_pages.dart' show ExecutionPlanPage;

class MissionDetailPage extends ConsumerWidget {
  const MissionDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        manager = ref.watch(sessionProvider).user!.role == AppRole.manager,
        path = '/api/missions/${segment(id)}';
    return Scaffold(
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
          final planning = manager && mission['status'] == 'PLANNING';
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '${mission['missionCode'] ?? ''}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              DetailFields(
                data: mission,
                fields: const {
                  'status': ('Status', 'Trạng thái'),
                  'orderTitle': ('Order', 'Đơn hàng'),
                  'description': ('Description', 'Mô tả'),
                  'serviceName': ('Service', 'Dịch vụ'),
                  'address': ('Site', 'Địa điểm'),
                  'scheduledStartAt': ('Start', 'Bắt đầu'),
                  'scheduledEndAt': ('End', 'Kết thúc'),
                  'customerName': ('Customer', 'Khách hàng'),
                  'flightPermitStatus': (
                    'Permit status',
                    'Trạng thái giấy phép',
                  ),
                  'lastRescheduleNote': ('Schedule note', 'Ghi chú lịch'),
                },
              ),
              for (final assignment in records(mission['staffAssignments']))
                Card(
                  child: ListTile(
                    title: Text('${assignment['staffName']}'),
                    subtitle: Text(
                      '${assignment['assignedRole']} · ${assignment['responseStatus']}',
                    ),
                    trailing: planning
                        ? IconButton(
                            tooltip: context.tr(
                              'Remove assignment',
                              'Gỡ phân công',
                            ),
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
                    trailing: planning
                        ? IconButton(
                            tooltip: context.tr(
                              'Remove assignment',
                              'Gỡ phân công',
                            ),
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
              if (manager) ...[
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => MissionReviewPage(missionId: id),
                    ),
                  ),
                  child: Text(
                    context.tr(
                      'Review evidence and report',
                      'Duyệt minh chứng và báo cáo',
                    ),
                  ),
                ),

                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ExecutionPlanPage(orderId: '${mission['orderId']}'),
                    ),
                  ),
                  child: Text(
                    context.tr(
                      'Order execution plan',
                      'Kế hoạch thực hiện đơn hàng',
                    ),
                  ),
                ),
                if (planning) ...[
                  FilledButton.tonal(
                    onPressed: () async {
                      final body = await editRecord(
                        context,
                        title: context.tr(
                          'Assign staff',
                          'Phân công nhân viên',
                        ),
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
                    child: Text(
                      context.tr('Assign staff', 'Phân công nhân viên'),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () async {
                      final body = await editRecord(
                        context,
                        title: context.tr(
                          'Assign device',
                          'Phân công thiết bị',
                        ),
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
                    child: Text(
                      context.tr('Assign device', 'Phân công thiết bị'),
                    ),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (await runAction(
                        context,
                        () => api.request(
                          '$path/confirm-planning',
                          method: 'POST',
                        ),
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
                        title: context.tr(
                          'Allocate checklist',
                          'Phân bổ hạng mục',
                        ),
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
                              for (final item in records(
                                order['checklistItems'],
                              ))
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
                    child: Text(
                      context.tr('Allocate checklist', 'Phân bổ hạng mục'),
                    ),
                  ),
                ],
                if (![
                  'COMPLETED',
                  'CANCELLED',
                  'FAILED',
                ].contains(mission['status']))
                  OutlinedButton(
                    onPressed: () async {
                      final body = await editRecord(
                        context,
                        title: context.tr('Reschedule', 'Đổi lịch'),
                        fields: const [
                          FieldSpec(
                            'scheduledStartAt',
                            'Start (device time zone)',
                            'Bắt đầu (múi giờ thiết bị)',
                            kind: FieldKind.instant,
                          ),
                          FieldSpec(
                            'scheduledEndAt',
                            'End (device time zone)',
                            'Kết thúc (múi giờ thiết bị)',
                            kind: FieldKind.instant,
                          ),
                          FieldSpec(
                            'reason',
                            'Reason',
                            'Lý do',
                            kind: FieldKind.choice,
                            options: {
                              'WEATHER_UNSAFE': 'Weather / Thời tiết',
                              'FLIGHT_PERMISSION_DELAY':
                                  'Permit delay / Chậm giấy phép',
                              'RESOURCE_UNAVAILABLE': 'Resources / Nguồn lực',
                              'EQUIPMENT_ISSUE': 'Equipment / Thiết bị',
                              'SITE_ACCESS_BLOCKED':
                                  'Site access / Tiếp cận địa điểm',
                              'CUSTOMER_REQUEST':
                                  'Customer request / Yêu cầu khách hàng',
                              'OTHER': 'Other / Khác',
                            },
                          ),
                          FieldSpec(
                            'note',
                            'Notes',
                            'Ghi chú',
                            kind: FieldKind.multiline,
                            required: false,
                          ),
                          FieldSpec(
                            'customerConfirmed',
                            'Customer confirmed',
                            'Khách hàng đã xác nhận',
                            kind: FieldKind.toggle,
                            required: false,
                          ),
                        ],
                        validate: (body) =>
                            '${body['scheduledStartAt']}'.compareTo(
                                  '${body['scheduledEndAt']}',
                                ) >=
                                0
                            ? context.tr(
                                'End must follow start.',
                                'Kết thúc phải sau bắt đầu.',
                              )
                            : null,
                      );
                      if (body != null &&
                          context.mounted &&
                          await runAction(
                            context,
                            () => api.request(
                              '$path/schedule',
                              method: 'PATCH',
                              body: {...body, 'scope': 'MISSION_ONLY'},
                            ),
                          )) {
                        reload();
                      }
                    },
                    child: Text(context.tr('Reschedule', 'Đổi lịch')),
                  ),
              ],
              if (!manager && permissions['canRespond'] == true) ...[
                FilledButton(
                  onPressed: () async {
                    if (await runAction(
                      context,
                      () =>
                          api.request('$path/accept-current', method: 'PATCH'),
                    )) {
                      reload();
                    }
                  },
                  child: Text(context.tr('Accept assignment', 'Nhận nhiệm vụ')),
                ),
                TextButton(
                  onPressed: () async {
                    final body = await editRecord(
                      context,
                      title: context.tr(
                        'Decline assignment',
                        'Từ chối nhiệm vụ',
                      ),
                      fields: const [
                        FieldSpec(
                          'reason',
                          'Reason',
                          'Lý do',
                          kind: FieldKind.multiline,
                        ),
                      ],
                    );
                    if (body != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            '$path/reject-current',
                            method: 'PATCH',
                            body: body,
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(context.tr('Decline', 'Từ chối')),
                ),
              ],
              if (!manager) ...[
                OutlinedButton(
                  onPressed: () =>
                      context.push('/staff/missions/${segment(id)}/checklist'),
                  child: Text(
                    context.tr(
                      'Monitoring checklist and inspection',
                      'Hạng mục giám sát và kiểm tra',
                    ),
                  ),
                ),
                if (permissions['canUploadMedia'] == true)
                  OutlinedButton(
                    onPressed: () =>
                        context.push('/staff/missions/${segment(id)}/media'),
                    child: Text(context.tr('Evidence files', 'Tệp minh chứng')),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
