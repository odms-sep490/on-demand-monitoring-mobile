import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/api_client.dart';
import '../../shared/portal_scaffold.dart';

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
  String notes = '';
  final restoredReplacements = <String, List<Json>>{};
  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider),
        path = '/api/manager/orders/${segment(widget.orderId)}';
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Publish results', 'Bàn giao kết quả')),
      ),
      body: RemoteView(
        load: () async => {
          'delivery': await api.request('$path/delivery/checklists'),
          'release': await optionalResource(api, '$path/delivery'),
          'draft': await optionalResource(api, '$path/delivery/draft'),
          'case': await optionalResource(api, '$path/result-revision-case'),
        },
        builder: (context, value, reload) {
          final delivery = object(object(value)['delivery']),
              revision = object(object(value)['case']);
          final checklists = records(delivery['checklists']);
          final draft = object(object(value)['draft']);
          List<Json> operations() => checklists.map((item) {
            final current = records(item['currentBundle']);
            final chosen =
                selection['${item['orderChecklistItemId']}'] ??
                current.map((e) => '${e['mediaAssetId']}').toList();
            final replacements =
                restoredReplacements['${item['orderChecklistItemId']}'] ??
                <Json>[];
            return {
              'orderChecklistItemId': item['orderChecklistItemId'],
              'addMediaAssetIds': chosen
                  .where(
                    (id) =>
                        !replacements.any(
                          (row) => row['newMediaAssetId'] == id,
                        ) &&
                        !current.any((e) => e['mediaAssetId'] == id),
                  )
                  .toList(),
              'removeRoundEvidenceIds': current
                  .where(
                    (e) =>
                        !chosen.contains(e['mediaAssetId']) &&
                        !replacements.any(
                          (row) =>
                              row['sourceRoundEvidenceId'] ==
                              e['roundEvidenceId'],
                        ),
                  )
                  .map((e) => e['roundEvidenceId'])
                  .where((id) => id != null)
                  .toList(),
              'replacements': replacements,
            };
          }).toList();
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
                                        required: false,
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
                                    setState(() {
                                      final key =
                                          '${item['orderChecklistItemId']}';
                                      restoredReplacements.remove(key);
                                      selection[key] =
                                          (body['ids'] as List? ?? [])
                                              .cast<String>();
                                    });
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
              if (draft['version'] != null) ...[
                if (draft['stale'] == true)
                  Text(
                    context.tr('The draft is stale.', 'Bản nháp đã lỗi thời.'),
                  ),
                OutlinedButton(
                  onPressed: publishing || draft['stale'] == true
                      ? null
                      : () {
                          setState(() {
                            notes = '${draft['notes'] ?? ''}';
                            selection.clear();
                            restoredReplacements.clear();
                            for (final item in checklists) {
                              final id = '${item['orderChecklistItemId']}';
                              final saved = records(draft['checklists'])
                                  .firstWhere(
                                    (row) =>
                                        row['orderChecklistItemId'] ==
                                        item['orderChecklistItemId'],
                                    orElse: () => <String, dynamic>{},
                                  );
                              final removed =
                                  (saved['removeRoundEvidenceIds'] as List? ??
                                          [])
                                      .toSet();
                              final replacements = records(
                                saved['replacements'],
                              );
                              final replaced = replacements
                                  .map((row) => row['sourceRoundEvidenceId'])
                                  .toSet();
                              restoredReplacements[id] = replacements;
                              selection[id] = {
                                for (final asset in records(
                                  item['currentBundle'],
                                ))
                                  if (!removed.contains(
                                        asset['roundEvidenceId'],
                                      ) &&
                                      !replaced.contains(
                                        asset['roundEvidenceId'],
                                      ))
                                    '${asset['mediaAssetId']}',
                                for (final asset
                                    in saved['addMediaAssetIds'] as List? ?? [])
                                  '$asset',
                                for (final row in replacements)
                                  '${row['newMediaAssetId']}',
                              }.toList();
                            }
                          });
                        },
                  child: Text(
                    context.tr('Restore server draft', 'Mở bản nháp đã lưu'),
                  ),
                ),
                TextButton(
                  onPressed: publishing
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                              title: Text(
                                context.tr(
                                  'Delete saved draft?',
                                  'Xóa bản nháp đã lưu?',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog, false),
                                  child: Text(context.tr('Cancel', 'Hủy')),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog, true),
                                  child: Text(context.tr('Delete', 'Xóa')),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          setState(() => publishing = true);
                          final deleted = await runAction(
                            context,
                            () => api.request(
                              '$path/delivery/draft',
                              method: 'DELETE',
                              query: {'expectedDraftVersion': draft['version']},
                            ),
                          );
                          if (!mounted) return;
                          setState(() => publishing = false);
                          if (deleted) reload();
                        },
                  child: Text(
                    context.tr('Delete server draft', 'Xóa bản nháp đã lưu'),
                  ),
                ),
              ],
              OutlinedButton(
                onPressed: publishing
                    ? null
                    : () async {
                        final body = await editRecord(
                          context,
                          title: context.tr(
                            'Save delivery draft',
                            'Lưu bản nháp bàn giao',
                          ),
                          initial: {'notes': notes},
                          fields: const [
                            FieldSpec(
                              'notes',
                              'Notes',
                              'Ghi chú',
                              kind: FieldKind.multiline,
                              required: false,
                            ),
                          ],
                        );
                        if (body == null || !context.mounted) return;
                        setState(() {
                          publishing = true;
                          notes = '${body['notes'] ?? ''}';
                        });
                        final saved = await runAction(
                          context,
                          () => api.request(
                            '$path/delivery/draft',
                            method: 'PUT',
                            body: {
                              'expectedDraftVersion': draft['version'] ?? 0,
                              'caseId': revision['caseId'],
                              'baseReviewRoundId':
                                  delivery['currentReviewRoundId'],
                              'expectedDeliveryVersion':
                                  delivery['deliveryVersion'],
                              'notes': notes,
                              'checklists': operations(),
                            },
                          ),
                        );
                        if (!mounted) return;
                        setState(() => publishing = false);
                        if (saved) reload();
                      },
                child: Text(context.tr('Save draft', 'Lưu bản nháp')),
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
                          initial: {'notes': notes},
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
                        final endpoint = '$path/delivery/checklists/publish';
                        final body = <String, dynamic>{
                          'expectedDeliveryVersion':
                              delivery['deliveryVersion'],
                          'baseReviewRoundId': delivery['currentReviewRoundId'],
                          'expectedReviewRoundVersion':
                              delivery['currentReviewRoundVersion'],
                          'notes': confirmation['notes'] ?? '',
                          'confirmSurplus': false,
                          'surplusConfirmationFingerprint': null,
                          'checklists': operations(),
                        };
                        bool published = false;
                        await runAction(context, () async {
                          try {
                            await api.command(endpoint, body: body);
                            published = true;
                          } on ApiFailure catch (failure) {
                            if (failure.code !=
                                'DELIVERY_SURPLUS_CONFIRMATION_REQUIRED') {
                              rethrow;
                            }
                            if (!context.mounted) return;
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialog) => AlertDialog(
                                title: Text(
                                  context.tr(
                                    'Publish surplus evidence?',
                                    'Bàn giao dư minh chứng?',
                                  ),
                                ),
                                content: Text(
                                  context.tr(
                                    'This selection exceeds the requested evidence count. Confirm to publish the full selection.',
                                    'Số minh chứng đã chọn vượt số lượng yêu cầu. Xác nhận để bàn giao toàn bộ.',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialog, false),
                                    child: Text(context.tr('Back', 'Quay lại')),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialog, true),
                                    child: Text(
                                      context.tr(
                                        'Confirm publish',
                                        'Xác nhận bàn giao',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            await api.command(
                              endpoint,
                              body: {
                                ...body,
                                'confirmSurplus': true,
                                'surplusConfirmationFingerprint':
                                    deliveryPublishFingerprint(
                                      widget.orderId,
                                      body,
                                    ),
                              },
                            );
                            published = true;
                          }
                          return null;
                        }, showSuccess: () => published);
                        if (mounted) {
                          setState(() => publishing = false);
                          if (published) {
                            selection.clear();
                            restoredReplacements.clear();
                            notes = '';
                            reload();
                          }
                        }
                      },
                child: Text(
                  context.tr('Publish to customer', 'Bàn giao cho khách hàng'),
                ),
              ),
              if ([
                'READY_FOR_DELIVERY',
                'PAYMENT_CONFIRMED',
              ].contains(object(object(value)['release'])['deliveryStatus']))
                FilledButton.icon(
                  icon: const Icon(Icons.download_done),
                  label: Text(
                    context.tr('Release originals', 'Bàn giao tệp gốc'),
                  ),
                  onPressed: publishing
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialog) => AlertDialog(
                              title: Text(
                                context.tr(
                                  'Release original files to the customer?',
                                  'Bàn giao tệp gốc cho khách hàng?',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialog, false),
                                  child: Text(context.tr('Back', 'Quay lại')),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(dialog, true),
                                  child: Text(
                                    context.tr('Release', 'Bàn giao'),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          setState(() => publishing = true);
                          final released = await runAction(
                            context,
                            () => api.request(
                              '$path/delivery/release-originals',
                              method: 'POST',
                            ),
                          );
                          if (!mounted) return;
                          setState(() => publishing = false);
                          if (released) reload();
                        },
                ),
              if (revision['active'] == true) ...[
                OutlinedButton(
                  onPressed: () async {
                    final body = await editRecord(
                      context,
                      title: context.tr(
                        'Create rework mission',
                        'Tạo nhiệm vụ bổ sung',
                      ),
                      fields: [
                        const FieldSpec('scopeLabel', 'Scope', 'Phạm vi'),
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
                          'caseItemIds',
                          'Rework items',
                          'Hạng mục bổ sung',
                          kind: FieldKind.multiChoice,
                          options: {
                            for (final item in records(
                              revision['items'],
                            ).where((e) => e['strategy'] == 'REWORK'))
                              '${item['caseItemId']}': '${item['title']}',
                          },
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
                            '/api/manager/result-revision-cases/${segment('${revision['caseId']}')}/rework-missions',
                            method: 'POST',
                            body: {
                              ...body,
                              'expectedCaseVersion': revision['version'],
                              'clientRequestId': newRequestId(),
                            },
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(
                    context.tr('Create rework mission', 'Tạo nhiệm vụ bổ sung'),
                  ),
                ),

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

String deliveryPublishFingerprint(String orderId, Json body) {
  final canonical = StringBuffer()
    ..writeln(orderId)
    ..writeln(body['baseReviewRoundId'] ?? '')
    ..writeln(body['expectedReviewRoundVersion'] ?? '')
    ..writeln((body['notes'] as String).trim());
  final items = records(body['checklists']).toList()
    ..sort(
      (a, b) => (a['orderChecklistItemId'] as String).compareTo(
        b['orderChecklistItemId'] as String,
      ),
    );
  for (final item in items) {
    canonical.write("${item['orderChecklistItemId']}|");
    for (final (key, prefix) in [
      ('addMediaAssetIds', 'A'),
      ('removeRoundEvidenceIds', 'D'),
    ]) {
      final ids = List<String>.from(item[key] as List)..sort();
      for (final id in ids) {
        canonical.write('$prefix:$id;');
      }
    }
    final replacements = records(item['replacements']).toList()
      ..sort(
        (a, b) => (a['sourceRoundEvidenceId'] as String).compareTo(
          b['sourceRoundEvidenceId'] as String,
        ),
      );
    for (final row in replacements) {
      canonical.write(
        "R:${row['sourceRoundEvidenceId']}:${row['newMediaAssetId']};",
      );
    }
    canonical.writeln();
  }
  return sha256.convert(utf8.encode(canonical.toString())).toString();
}
