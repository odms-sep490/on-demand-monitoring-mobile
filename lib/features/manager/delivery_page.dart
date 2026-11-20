import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/external_link.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../customer/finance_page.dart' show optionalResource;

class ManagerDeliveryPage extends ConsumerStatefulWidget {
  const ManagerDeliveryPage({super.key, required this.orderId});
  final String orderId;
  @override
  ConsumerState<ManagerDeliveryPage> createState() =>
      _ManagerDeliveryPageState();
}

class _ManagerDeliveryPageState extends ConsumerState<ManagerDeliveryPage> {
  final Map<String, List<String>> selection = {};
  bool publishing = false;
  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider),
        path = '/api/manager/orders/${segment(widget.orderId)}';
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Publish results', 'Bàn giao kết quả')),
      ),
      body: RemoteView(
        load: () async => {
          'delivery': await api.request('$path/delivery/checklists'),
          'case': await optionalResource(api, '$path/result-revision-case'),
        },
        builder: (context, value, reload) {
          final delivery = object(object(value)['delivery']),
              revision = object(object(value)['case']);
          final checklists = records(delivery['checklists']);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DetailFields(
                data: delivery,
                fields: const {
                  'deliveryStatus': ('Delivery status', 'Trạng thái bàn giao'),
                  'deliveryVersion': ('Version', 'Phiên bản'),
                },
              ),
              for (final item in checklists)
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
                        for (final asset in records(item['currentBundle']))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${asset['fileName']}'),
                            onTap: asset['previewUrl'] == null
                                ? null
                                : () => runAction(
                                    context,
                                    () => openExternal(asset['previewUrl']),
                                  ),
                          ),
                        OutlinedButton(
                          onPressed: publishing
                              ? null
                              : () async {
                                  final assets = <String, Json>{
                                    for (final asset in [
                                      ...records(item['currentBundle']),
                                      ...records(item['eligibleMedia']),
                                    ])
                                      '${asset['mediaAssetId']}': asset,
                                  };
                                  final body = await editRecord(
                                    context,
                                    title: '${item['title']}',
                                    fields: [
                                      FieldSpec(
                                        'ids',
                                        'Customer evidence selection',
                                        'Minh chứng bàn giao cho khách',
                                        kind: FieldKind.multiChoice,
                                        initial:
                                            selection['${item['orderChecklistItemId']}'] ??
                                            records(item['currentBundle'])
                                                .map(
                                                  (e) => '${e['mediaAssetId']}',
                                                )
                                                .toList(),
                                        options: {
                                          for (final entry in assets.entries)
                                            entry.key:
                                                '${entry.value['fileName']}',
                                        },
                                      ),
                                    ],
                                  );
                                  if (body != null && mounted) {
                                    setState(
                                      () =>
                                          selection['${item['orderChecklistItemId']}'] =
                                              (body['ids'] as List)
                                                  .cast<String>(),
                                    );
                                  }
                                },
                          child: Text(
                            context.tr('Choose evidence', 'Chọn minh chứng'),
                          ),
                        ),
                        if (selection.containsKey(
                          '${item['orderChecklistItemId']}',
                        ))
                          Text(
                            context.tr(
                              '${selection['${item['orderChecklistItemId']}']!.length} selected',
                              'Đã chọn ${selection['${item['orderChecklistItemId']}']!.length} tệp',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              FilledButton(
                onPressed: publishing
                    ? null
                    : () async {
                        final confirmation = await editRecord(
                          context,
                          title: context.tr(
                            'Publish results',
                            'Bàn giao kết quả',
                          ),
                          fields: const [
                            FieldSpec(
                              'notes',
                              'Delivery note',
                              'Ghi chú bàn giao',
                              kind: FieldKind.multiline,
                              required: false,
                            ),
                            FieldSpec(
                              'confirmed',
                              'Confirm these results are ready for the customer',
                              'Xác nhận kết quả sẵn sàng bàn giao',
                              kind: FieldKind.toggle,
                            ),
                          ],
                        );
                        if (confirmation == null || !context.mounted) return;
                        setState(() => publishing = true);
                        final saved = await runAction(
                          context,
                          () => api.request(
                            '$path/delivery/checklists/publish',
                            method: 'POST',
                            body: {
                              'clientRequestId':
                                  'mobile-${DateTime.now().microsecondsSinceEpoch}',
                              'expectedDeliveryVersion':
                                  delivery['deliveryVersion'],
                              'baseReviewRoundId':
                                  delivery['currentReviewRoundId'],
                              'expectedReviewRoundVersion':
                                  delivery['currentReviewRoundVersion'],
                              'notes': confirmation['notes'] ?? '',
                              'confirmSurplus': false,
                              'surplusConfirmationFingerprint': null,
                              'checklists': checklists.map((item) {
                                final current = records(item['currentBundle']);
                                final chosen =
                                    selection['${item['orderChecklistItemId']}'] ??
                                    current
                                        .map((e) => '${e['mediaAssetId']}')
                                        .toList();
                                return {
                                  'orderChecklistItemId':
                                      item['orderChecklistItemId'],
                                  'addMediaAssetIds': chosen
                                      .where(
                                        (id) => !current.any(
                                          (e) => e['mediaAssetId'] == id,
                                        ),
                                      )
                                      .toList(),
                                  'removeRoundEvidenceIds': current
                                      .where(
                                        (e) =>
                                            !chosen.contains(e['mediaAssetId']),
                                      )
                                      .map((e) => e['roundEvidenceId'])
                                      .where((id) => id != null)
                                      .toList(),
                                  'replacements': <Object>[],
                                };
                              }).toList(),
                            },
                          ),
                        );
                        if (mounted) {
                          setState(() => publishing = false);
                          if (saved) {
                            selection.clear();
                            reload();
                          }
                        }
                      },
                child: Text(
                  context.tr('Publish to customer', 'Bàn giao cho khách hàng'),
                ),
              ),
              if (revision['active'] == true) ...[
                const Divider(height: 40),
                Text(
                  context.tr('Revision case', 'Yêu cầu chỉnh sửa'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final item in records(revision['items']))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('${item['title']}'),
                          DetailFields(
                            data: item,
                            fields: const {
                              'scopeDecision': (
                                'Scope decision',
                                'Quyết định phạm vi',
                              ),
                              'strategy': ('Resolution', 'Phương án'),
                              'managerInstructions': (
                                'Instructions',
                                'Hướng dẫn',
                              ),
                            },
                          ),
                          for (final feedback in records(item['feedback']))
                            Text('${feedback['customerNote'] ?? ''}'),
                          OutlinedButton(
                            onPressed: () async {
                              final body = await editRecord(
                                context,
                                title: context.tr(
                                  'Revision decision',
                                  'Quyết định chỉnh sửa',
                                ),
                                fields: const [
                                  FieldSpec(
                                    'scopeDecision',
                                    'Scope',
                                    'Phạm vi',
                                    kind: FieldKind.choice,
                                    options: {
                                      'IN_SCOPE': 'In scope / Trong phạm vi',
                                      'OUT_OF_SCOPE':
                                          'Out of scope / Ngoài phạm vi',
                                    },
                                  ),
                                  FieldSpec(
                                    'strategy',
                                    'Resolution',
                                    'Phương án',
                                    kind: FieldKind.choice,
                                    options: {
                                      'UNDECIDED':
                                          'Undecided / Chưa quyết định',
                                      'RESERVE_MEDIA': 'Existing evidence / Minh chứng có sẵn',
                                      'REWORK':
                                          'Rework mission / Nhiệm vụ bổ sung',
                                    },
                                  ),
                                  FieldSpec(
                                    'reason',
                                    'Reason',
                                    'Lý do',
                                    kind: FieldKind.multiline,
                                  ),
                                  FieldSpec(
                                    'managerInstructions',
                                    'Instructions',
                                    'Hướng dẫn',
                                    kind: FieldKind.multiline,
                                  ),
                                ],
                              );
                              if (body != null &&
                                  context.mounted &&
                                  await runAction(
                                    context,
                                    () => api.request(
                                      '/api/manager/result-revision-cases/${segment('${revision['caseId']}')}/items/${segment('${item['caseItemId']}')}/decision',
                                      method: 'PUT',
                                      body: {
                                        ...body,
                                        'expectedVersion': item['version'],
                                      },
                                    ),
                                  )) {
                                reload();
                              }
                            },
                            child: Text(
                              context.tr('Decide resolution', 'Chọn phương án'),
                            ),
                          ),
                        ],
                      ),
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
