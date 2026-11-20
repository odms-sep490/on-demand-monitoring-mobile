import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class OrderReadinessPage extends ConsumerWidget {
  const OrderReadinessPage({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final path = '/api/manager/orders/${segment(orderId)}/readiness';
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Order readiness', 'Điều kiện duyệt đơn')),
      ),
      body: RemoteView(
        load: () => api.request(path),
        builder: (context, data, reload) {
          final readiness = object(data);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                readiness['canApprove'] == true
                    ? context.tr('Ready for approval', 'Đủ điều kiện duyệt')
                    : context.tr(
                        'Approval is blocked',
                        'Chưa đủ điều kiện duyệt',
                      ),
              ),
              if (readiness['blockingReasons'] case final List reasons)
                for (final reason in reasons)
                  ListTile(
                    leading: const Icon(Icons.warning_amber),
                    title: Text('$reason'),
                  ),
              for (final criterion in records(readiness['criteria']))
                Card(
                  child: ListTile(
                    title: Text('${criterion['title']}'),
                    subtitle: DetailFields(
                      data: criterion,
                      fields: const {
                        'description': ('Description', 'Mô tả'),
                        'result': ('Result', 'Kết quả'),
                        'reason': ('Explanation', 'Giải thích'),
                        'note': ('Note', 'Ghi chú'),
                        'decidedByName': ('Reviewed by', 'Người đánh giá'),
                        'decidedAt': ('Reviewed at', 'Thời điểm đánh giá'),
                      },
                    ),
                    trailing: criterion['type'] != 'MANUAL'
                        ? null
                        : IconButton(
                            tooltip: context.tr(
                              'Edit assessment',
                              'Sửa đánh giá',
                            ),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              const results = {
                                'PASS': 'Pass / Đạt',
                                'WARN': 'Warning / Cảnh báo',
                                'FAIL': 'Fail / Không đạt',
                              };
                              final body = await editRecord(
                                context,
                                title: '${criterion['title']}',
                                fields: const [
                                  FieldSpec(
                                    'result',
                                    'Result',
                                    'Kết quả',
                                    kind: FieldKind.choice,
                                    options: results,
                                  ),
                                  FieldSpec(
                                    'note',
                                    'Note',
                                    'Ghi chú',
                                    kind: FieldKind.multiline,
                                    required: false,
                                  ),
                                ],
                                initial: {
                                  if (results.containsKey(criterion['result']))
                                    'result': criterion['result'],
                                  'note': criterion['note'],
                                },
                              );
                              if (body == null || !context.mounted) return;
                              if (await runAction(
                                context,
                                () => api.request(
                                  '$path/${segment('${criterion['code']}')}',
                                  method: 'PUT',
                                  body: body,
                                ),
                              )) {
                                reload();
                              }
                            },
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
