import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/external_link.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class ResultsPage extends ConsumerWidget {
  const ResultsPage({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        path = '/api/orders/${segment(orderId)}';
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Delivered results', 'Kết quả bàn giao')),
      ),
      body: RemoteView(
        load: () => api.request('$path/result-review', query: {'size': 100}),
        builder: (context, data, reload) {
          final review = object(data), items = records(object(data)['items']);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DetailFields(
                data: review,
                fields: const {
                  'roundNumber': ('Review round', 'Vòng đánh giá'),
                  'publishedAt': ('Published', 'Công bố'),
                  'blockedReason': ('Availability', 'Tình trạng'),
                },
              ),
              for (final item in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${item['title']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        DetailFields(
                          data: item,
                          fields: const {
                            'description': ('Description', 'Mô tả'),
                            'expectedOutputs': (
                              'Expected outputs',
                              'Đầu ra mong đợi',
                            ),
                          },
                        ),
                        for (final evidence in records(item['evidence']))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${evidence['fileName']}'),
                            subtitle: Text(
                              '${evidence['accessReason'] ?? evidence['type']}',
                            ),
                            trailing: evidence['url'] == null
                                ? null
                                : IconButton(
                                    onPressed: () => runAction(
                                      context,
                                      () => openExternal(evidence['url']),
                                    ),
                                    icon: const Icon(Icons.open_in_new),
                                  ),
                          ),
                        if (review['canSubmitRevision'] == true &&
                            item['canRequestRevision'] != false)
                          OutlinedButton(
                            onPressed: () async {
                              final body = await editRecord(
                                context,
                                title: context.tr(
                                  'Request revision',
                                  'Yêu cầu chỉnh sửa',
                                ),
                                fields: const [
                                  FieldSpec(
                                    'reasonCode',
                                    'Reason',
                                    'Lý do',
                                    kind: FieldKind.choice,
                                    options: {
                                      'MISSING_EVIDENCE':
                                          'Missing evidence / Thiếu minh chứng',
                                      'POOR_QUALITY':
                                          'Poor quality / Chất lượng kém',
                                      'WRONG_LOCATION':
                                          'Wrong location / Sai vị trí',
                                      'REQUIREMENT_NOT_MET':
                                          'Requirement not met / Chưa đáp ứng',
                                      'OTHER': 'Other / Khác',
                                    },
                                  ),
                                  FieldSpec(
                                    'note',
                                    'Details',
                                    'Chi tiết',
                                    kind: FieldKind.multiline,
                                  ),
                                ],
                              );
                              if (body != null &&
                                  context.mounted &&
                                  await runAction(
                                    context,
                                    () => api.request(
                                      '$path/result/revision-request',
                                      method: 'POST',
                                      body: {
                                        'reviewRoundId':
                                            review['reviewRoundId'],
                                        'expectedRoundVersion':
                                            review['roundVersion'],
                                        'clientRequestId':
                                            'mobile-${DateTime.now().microsecondsSinceEpoch}',
                                        'generalNote': body['note'],
                                        'items': [
                                          {
                                            'roundItemId': item['roundItemId'],
                                            ...body,
                                            'roundEvidenceIds':
                                                records(item['evidence'])
                                                    .map(
                                                      (e) =>
                                                          e['roundEvidenceId'],
                                                    )
                                                    .toList(),
                                          },
                                        ],
                                      },
                                    ),
                                  )) {
                                reload();
                              }
                            },
                            child: Text(
                              context.tr(
                                'Request revision',
                                'Yêu cầu chỉnh sửa',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (review['canAcceptResult'] == true)
                FilledButton(
                  onPressed: () async {
                    final accepted = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(
                          context.tr(
                            'Accept these results?',
                            'Chấp nhận kết quả này?',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.tr('Back', 'Quay lại')),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(context.tr('Accept', 'Chấp nhận')),
                          ),
                        ],
                      ),
                    );
                    if (accepted == true &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            '$path/result/accept',
                            method: 'POST',
                            body: {
                              'expectedReviewRoundId': review['reviewRoundId'],
                              'expectedRoundVersion': review['roundVersion'],
                            },
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(
                    context.tr('Accept results', 'Chấp nhận kết quả'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
