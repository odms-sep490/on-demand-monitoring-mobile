import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/external_link.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../customer/finance_page.dart' show optionalResource;
import '../devices/device_pages.dart' show allPages;

class MissionReviewPage extends ConsumerWidget {
  const MissionReviewPage({super.key, required this.missionId});
  final String missionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        path = '/api/manager/missions/${segment(missionId)}/media-approvals';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            'Review evidence and report',
            'Duyệt minh chứng và báo cáo',
          ),
        ),
      ),
      body: RemoteView(
        load: () async => {
          'media': await allPages(api, path),
          'result': await optionalResource(
            api,
            '/api/missions/${segment(missionId)}/result',
          ),
        },
        builder: (context, value, reload) {
          final result = object(object(value)['result']);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              for (final item in records(object(value)['media']))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${item['fileName']}'),
                        const SizedBox(height: 12),
                        if (item['thumbnailUrl'] != null)
                          Image.network(
                            '${item['thumbnailUrl']}',
                            height: 200,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.image_not_supported_outlined),
                          ),
                        if (item['previewUrl'] != null)
                          OutlinedButton(
                            onPressed: () => runAction(
                              context,
                              () => openExternal(item['previewUrl']),
                            ),
                            child: Text(
                              context.tr('View evidence', 'Xem minh chứng'),
                            ),
                          ),
                        FilledButton(
                          onPressed: () async {
                            if (await runAction(
                              context,
                              () => api.request(
                                '$path/${segment('${item['mediaId']}')}/approve',
                                method: 'POST',
                              ),
                            )) {
                              reload();
                            }
                          },
                          child: Text(
                            context.tr('Approve evidence', 'Duyệt minh chứng'),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (await runAction(
                              context,
                              () => api.request(
                                '$path/${segment('${item['mediaId']}')}/reject',
                                method: 'POST',
                              ),
                            )) {
                              reload();
                            }
                          },
                          child: Text(
                            context.tr('Reject evidence', 'Từ chối minh chứng'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 40),
              DetailFields(
                data: result,
                fields: const {
                  'summary': ('Report summary', 'Tóm tắt báo cáo'),
                  'notes': ('Notes', 'Ghi chú'),
                  'approvalStatus': ('Approval status', 'Trạng thái duyệt'),
                },
              ),
              if (result['approvalStatus'] == 'PENDING_MANAGER_APPROVAL') ...[
                FilledButton(
                  onPressed: () async {
                    if (await runAction(
                      context,
                      () => api.request(
                        '/api/manager/mission-results/${segment('${result['id']}')}/approve',
                        method: 'POST',
                        body: {},
                      ),
                    )) {
                      reload();
                    }
                  },
                  child: Text(context.tr('Approve report', 'Duyệt báo cáo')),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final body = await editRecord(
                      context,
                      title: context.tr(
                        'Request report corrections',
                        'Yêu cầu sửa báo cáo',
                      ),
                      fields: const [
                        FieldSpec(
                          'note',
                          'Correction instructions',
                          'Hướng dẫn sửa',
                          kind: FieldKind.multiline,
                        ),
                      ],
                    );
                    if (body != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            '/api/manager/mission-results/${segment('${result['id']}')}/reject',
                            method: 'POST',
                            body: body,
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(
                    context.tr('Request corrections', 'Yêu cầu chỉnh sửa'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
