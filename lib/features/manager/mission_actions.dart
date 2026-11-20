import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/files.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class ManagerMissionActions extends ConsumerWidget {
  const ManagerMissionActions({
    super.key,
    required this.mission,
    required this.permissions,
    required this.reload,
  });
  final Json mission, permissions;
  final VoidCallback reload;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        path = '/api/missions/${segment('${mission['id']}')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!['COMPLETED', 'CANCELLED', 'FAILED'].contains(mission['status']))
          OutlinedButton(
            onPressed: () async {
              try {
                final body = await editRecord(
                  context,
                  title: context.tr('Mission permit', 'Giấy phép nhiệm vụ'),
                  fields: const [
                    FieldSpec(
                      'status',
                      'Status',
                      'Trạng thái',
                      kind: FieldKind.choice,
                      options: {
                        'NOT_REQUESTED': 'Not requested / Chưa yêu cầu',
                        'PENDING': 'Pending / Chờ duyệt',
                        'APPROVED': 'Approved / Đã duyệt',
                        'REJECTED': 'Rejected / Từ chối',
                      },
                    ),
                    FieldSpec(
                      'note',
                      'Permit note',
                      'Ghi chú giấy phép',
                      kind: FieldKind.multiline,
                      required: false,
                    ),
                    FieldSpec(
                      'attachFile',
                      'Attach permit file',
                      'Đính kèm giấy phép',
                      kind: FieldKind.toggle,
                      required: false,
                    ),
                  ],
                );
                if (body == null || !context.mounted) return;
                if (body.remove('attachFile') == true) {
                  final files = await pickOneFile(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                  );
                  if (files.isEmpty) return;
                  final doc = await inlineDocument(files.single);
                  body.addAll({
                    'fileName': doc['fileName'],
                    'contentType': doc['contentType'],
                    'dataUrl': doc['dataUrl'],
                  });
                }
                if (context.mounted &&
                    await runAction(
                      context,
                      () => api.request(
                        '$path/flight-permit',
                        method: 'PATCH',
                        body: body,
                      ),
                    )) {
                  reload();
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$error')));
                }
              }
            },
            child: Text(
              context.tr(
                'Update mission permit',
                'Cập nhật giấy phép nhiệm vụ',
              ),
            ),
          ),
        if (permissions['canCancelMission'] == true)
          TextButton(
            onPressed: () async {
              try {
                final plan = object(
                  await api.request(
                    '/api/orders/${segment('${mission['orderId']}')}/execution-plan',
                  ),
                );
                if (!context.mounted) return;
                final body = await editRecord(
                  context,
                  title: context.tr('Cancel mission', 'Hủy nhiệm vụ'),
                  fields: const [
                    FieldSpec(
                      'reason',
                      'Cancellation reason',
                      'Lý do hủy',
                      kind: FieldKind.multiline,
                    ),
                  ],
                );
                if (body != null &&
                    context.mounted &&
                    await runAction(
                      context,
                      () => api.request(
                        '$path/cancel',
                        method: 'POST',
                        body: {
                          ...body,
                          'expectedPlanRevision': plan['revision'],
                        },
                      ),
                    )) {
                  reload();
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$error')));
                }
              }
            },
            child: Text(context.tr('Cancel mission', 'Hủy nhiệm vụ')),
          ),
      ],
    );
  }
}
