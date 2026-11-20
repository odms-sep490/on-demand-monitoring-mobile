import '../../shared/portal_scaffold.dart';

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
    return PortalScaffold(
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
                      ],
                    ),
                  ),
                ),
              if (review['canSubmitRevision'] == true &&
                  items.any((item) => item['canRequestRevision'] != false))
                OutlinedButton(
                  onPressed: () async {
                    final body = await collectRevision(context, review, items);
                    if (body != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.command(
                            '$path/result/revision-request',
                            body: body,
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(
                    context.tr('Request revision', 'Yêu cầu chỉnh sửa'),
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

Future<Json?> collectRevision(
  BuildContext context,
  Json review,
  List<Json> items,
) async {
  final eligible = {
    for (final item in items)
      if (item['canRequestRevision'] != false && item['roundItemId'] is String)
        item['roundItemId'] as String: item,
  };
  final selection = await editRecord(
    context,
    title: context.tr('Request revision', 'Yêu cầu chỉnh sửa'),
    fields: [
      FieldSpec(
        'items',
        'Checklist items to revise',
        'Hạng mục cần chỉnh sửa',
        kind: FieldKind.multiChoice,
        options: eligible.map((id, item) => MapEntry(id, '${item['title']}')),
      ),
      const FieldSpec(
        'generalNote',
        'General note',
        'Ghi chú chung',
        kind: FieldKind.multiline,
        required: false,
      ),
    ],
    validate: (values) => validateRevisionNotes(context, values),
  );
  if (selection == null || !context.mounted) return null;
  final selected = (selection['items'] as List).cast<String>();
  final details = await editRecord(
    context,
    title: context.tr('Revision details', 'Chi tiết chỉnh sửa'),
    fields: [
      for (final id in selected) ...[
        FieldSpec(
          'reason:$id',
          '${eligible[id]!['title']} — reason',
          '${eligible[id]!['title']} — lý do',
          kind: FieldKind.choice,
          options: const {
            'MISSING_EVIDENCE': 'Missing evidence / Thiếu minh chứng',
            'POOR_QUALITY': 'Poor quality / Chất lượng kém',
            'WRONG_LOCATION': 'Wrong location / Sai vị trí',
            'REQUIREMENT_NOT_MET': 'Requirement not met / Chưa đáp ứng',
            'OTHER': 'Other / Khác',
          },
        ),
        FieldSpec(
          'note:$id',
          'Details',
          'Chi tiết',
          kind: FieldKind.multiline,
          required: false,
        ),
        if (records(eligible[id]!['evidence'])
            .any((e) => e['roundEvidenceId'] is String))
          FieldSpec(
            'evidence:$id',
            'Related evidence',
            'Minh chứng liên quan',
            kind: FieldKind.multiChoice,
            required: false,
            options: {
              for (final e in records(eligible[id]!['evidence']))
                if (e['roundEvidenceId'] is String)
                  e['roundEvidenceId'] as String: '${e['fileName']}',
            },
          ),
      ],
    ],
    validate: (values) => validateRevisionNotes(context, values),
  );
  if (details == null) return null;
  return {
    'reviewRoundId': review['reviewRoundId'],
    'expectedRoundVersion': review['roundVersion'],
    'generalNote': selection['generalNote'] ?? '',
    'items': [
      for (final id in selected)
        {
          'roundItemId': id,
          'reasonCode': details['reason:$id'],
          'note': details['note:$id'] ?? '',
          'roundEvidenceIds': details['evidence:$id'] ?? <String>[],
        },
    ],
  };
}

String? validateRevisionNotes(BuildContext context, Json values) =>
    values.entries.any(
      (e) =>
          (e.key == 'generalNote' || e.key.startsWith('note:')) &&
          e.value is String &&
          (e.value as String).length > 2000,
    )
    ? context.tr(
        'Notes must be at most 2,000 characters.',
        'Ghi chú tối đa 2.000 ký tự.',
      )
    : null;
