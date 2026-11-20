import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/external_link.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class ChecklistPage extends ConsumerWidget {
  const ChecklistPage({super.key, required this.missionId});
  final String missionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        path = '/api/missions/${segment(missionId)}';
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Monitoring inspection', 'Kiểm tra giám sát')),
      ),
      body: RemoteView(
        load: () async => {
          'checklist': await api.request('$path/checklist-executions'),
          'permissions': await api.request('$path/permissions'),
        },
        builder: (context, data, reload) {
          final checklist = object(object(data)['checklist']),
              permissions = object(object(data)['permissions']);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DetailFields(
                data: checklist,
                fields: const {
                  'blockingReasons': ('Needs resolution', 'Cần xử lý'),
                },
              ),
              for (final item in records(checklist['executions']))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${item['content']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        DetailFields(
                          data: item,
                          fields: const {
                            'description': ('Description', 'Mô tả'),
                            'executionSteps': (
                              'Execution steps',
                              'Các bước thực hiện',
                            ),
                            'inputRequirements': ('Inputs', 'Đầu vào'),
                            'expectedOutputs': (
                              'Expected outputs',
                              'Đầu ra mong đợi',
                            ),
                            'executionStatus': ('Execution', 'Thực hiện'),
                            'assessmentStatus': ('Assessment', 'Đánh giá'),
                            'observation': ('Observation', 'Nhận xét'),
                            'assessmentNote': (
                              'Assessment note',
                              'Ghi chú đánh giá',
                            ),
                            'blockingReasons': (
                              'Needs resolution',
                              'Cần xử lý',
                            ),
                          },
                        ),
                        if (permissions['canExecuteMonitoringChecklist'] ==
                                true ||
                            permissions['canAssessMonitoringChecklist'] == true)
                          FilledButton.tonal(
                            onPressed: () async {
                              final body = await editRecord(
                                context,
                                title: context.tr(
                                  'Update requirement',
                                  'Cập nhật hạng mục',
                                ),
                                initial: item,
                                fields: [
                                  if (permissions['canExecuteMonitoringChecklist'] ==
                                      true) ...[
                                    const FieldSpec(
                                      'executionStatus',
                                      'Execution status',
                                      'Trạng thái thực hiện',
                                      kind: FieldKind.choice,
                                      options: {
                                        'PENDING': 'Pending / Chưa thực hiện',
                                        'IN_PROGRESS':
                                            'In progress / Đang thực hiện',
                                        'COMPLETED': 'Completed / Hoàn thành',
                                        'UNABLE_TO_VERIFY': 'Unable to verify / Không thể xác minh',
                                      },
                                    ),
                                    const FieldSpec(
                                      'observation',
                                      'Observation',
                                      'Nhận xét',
                                      kind: FieldKind.multiline,
                                      required: false,
                                    ),
                                    const FieldSpec(
                                      'unableToVerifyReason',
                                      'Reason if unable to verify',
                                      'Lý do nếu không thể xác minh',
                                      kind: FieldKind.multiline,
                                      required: false,
                                    ),
                                  ],
                                  if (permissions['canAssessMonitoringChecklist'] ==
                                      true) ...[
                                    const FieldSpec(
                                      'assessmentStatus',
                                      'Assessment',
                                      'Đánh giá',
                                      kind: FieldKind.choice,
                                      options: {
                                        'NOT_ASSESSED':
                                            'Not assessed / Chưa đánh giá',
                                        'COMPLIANT': 'Compliant / Đạt',
                                        'NON_COMPLIANT':
                                            'Non-compliant / Không đạt',
                                      },
                                    ),
                                    const FieldSpec(
                                      'assessmentNote',
                                      'Assessment note',
                                      'Ghi chú đánh giá',
                                      kind: FieldKind.multiline,
                                      required: false,
                                    ),
                                  ],
                                ],
                              );
                              if (body != null &&
                                  context.mounted &&
                                  await runAction(
                                    context,
                                    () => api.request(
                                      '$path/checklist-executions/${segment('${item['id']}')}',
                                      method: 'PATCH',
                                      body: {
                                        'expectedVersion': item['version'],
                                        'executionStatus':
                                            item['executionStatus'],
                                        'assessmentStatus':
                                            item['assessmentStatus'],
                                        ...body,
                                      },
                                    ),
                                  )) {
                                reload();
                              }
                            },
                            child: Text(context.tr('Update', 'Cập nhật')),
                          ),
                        for (final evidence in records(item['evidence']))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${evidence['fileName']}'),
                            subtitle: Text('${evidence['mediaStatus']}'),
                            onTap: evidence['previewUrl'] == null
                                ? null
                                : () => runAction(
                                    context,
                                    () => openExternal(evidence['previewUrl']),
                                  ),
                            trailing:
                                permissions['canDetachChecklistEvidence'] ==
                                    true
                                ? IconButton(
                                    icon: const Icon(Icons.link_off),
                                    onPressed: () async {
                                      if (await runAction(
                                        context,
                                        () => api.request(
                                          '$path/checklist-executions/${segment('${item['id']}')}/evidence/${segment('${evidence['evidenceId']}')}',
                                          method: 'DELETE',
                                          query: {
                                            'expectedVersion': item['version'],
                                          },
                                        ),
                                      )) {
                                        reload();
                                      }
                                    },
                                  )
                                : null,
                          ),
                        if (permissions['canAttachChecklistEvidence'] == true)
                          OutlinedButton(
                            onPressed: () async {
                              final candidates = records(
                                await api.request(
                                  '$path/checklist-evidence/candidates',
                                  query: {'page': 0, 'size': 50},
                                ),
                              ).where((e) => e['attachable'] == true);
                              if (!context.mounted) return;
                              final body = await editRecord(
                                context,
                                title: context.tr(
                                  'Attach evidence',
                                  'Gắn minh chứng',
                                ),
                                fields: [
                                  FieldSpec(
                                    'mediaId',
                                    'Evidence',
                                    'Minh chứng',
                                    kind: FieldKind.choice,
                                    options: {
                                      for (final e in candidates)
                                        '${e['mediaId']}': '${e['fileName']}',
                                    },
                                  ),
                                ],
                              );
                              if (body != null &&
                                  context.mounted &&
                                  await runAction(
                                    context,
                                    () => api.request(
                                      '$path/checklist-executions/${segment('${item['id']}')}/evidence/${segment('${body['mediaId']}')}',
                                      method: 'PUT',
                                      body: {
                                        'expectedVersion': item['version'],
                                      },
                                    ),
                                  )) {
                                reload();
                              }
                            },
                            child: Text(
                              context.tr('Attach evidence', 'Gắn minh chứng'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (permissions['canSubmitMissionResult'] == true &&
                  checklist['readyForSubmission'] == true)
                FilledButton(
                  onPressed: () async {
                    final body = await editRecord(
                      context,
                      title: context.tr('Submit report', 'Nộp báo cáo'),
                      fields: const [
                        FieldSpec(
                          'summary',
                          'Summary',
                          'Tóm tắt',
                          kind: FieldKind.multiline,
                        ),
                        FieldSpec(
                          'notes',
                          'Notes',
                          'Ghi chú',
                          kind: FieldKind.multiline,
                          required: false,
                        ),
                      ],
                    );
                    if (body != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            '$path/result',
                            method: 'POST',
                            body: {'status': 'COMPLETED', ...body},
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(
                    context.tr(
                      'Submit report for review',
                      'Nộp báo cáo chờ duyệt',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
