import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class PricingPage extends ConsumerWidget {
  const PricingPage({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        path = '/api/manager/orders/${segment(orderId)}';
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Pricing review', 'Duyệt giá'))),
      body: RemoteView(
        load: () => api.request('$path/pricing'),
        builder: (context, value, reload) {
          final pricing = object(value),
              quote = object(object(value)['currentQuote']),
              calculation = object(object(value)['systemCalculation']);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DetailFields(
                data: pricing,
                fields: const {
                  'orderCode': ('Order', 'Đơn hàng'),
                  'serviceName': ('Service', 'Dịch vụ'),
                  'basePackagePrice': ('Base price (VND)', 'Giá cơ bản (VND)'),
                },
              ),
              DetailFields(
                data: calculation,
                fields: const {
                  'systemCalculatedAmount': (
                    'Calculated amount (VND)',
                    'Giá tính toán (VND)',
                  ),
                },
              ),
              for (final item in records(pricing['checklistItems']))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${item['content']}'),
                        const SizedBox(height: 12),
                        DetailFields(
                          data: item,
                          fields: const {
                            'reviewStatus': ('Review', 'Duyệt'),
                            'systemCalculatedPrice': (
                              'Calculated (VND)',
                              'Giá tính (VND)',
                            ),
                            'managerApprovedAmount': (
                              'Approved (VND)',
                              'Giá duyệt (VND)',
                            ),
                            'managerNote': ('Note', 'Ghi chú'),
                          },
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            final body = await editRecord(
                              context,
                              title: context.tr(
                                'Review requirement',
                                'Duyệt hạng mục',
                              ),
                              initial: {
                                'status': item['reviewStatus'],
                                'managerNote': item['managerNote'],
                              },
                              fields: const [
                                FieldSpec(
                                  'status',
                                  'Decision',
                                  'Quyết định',
                                  kind: FieldKind.choice,
                                  options: {
                                    'PENDING': 'Pending / Chờ duyệt',
                                    'INCLUDED': 'Included / Bao gồm',
                                    'ADDITIONAL': 'Additional / Bổ sung',
                                    'DUPLICATE': 'Duplicate / Trùng lặp',
                                    'REJECTED': 'Rejected / Từ chối',
                                  },
                                ),
                                FieldSpec(
                                  'managerNote',
                                  'Note',
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
                                    '$path/checklist-items/${segment('${item['id']}')}',
                                    method: 'PATCH',
                                    body: {
                                      ...body,
                                      'expectedChecklistRevision':
                                          pricing['checklistRevision'],
                                    },
                                  ),
                                )) {
                              reload();
                            }
                          },
                          child: Text(
                            context.tr('Review requirement', 'Duyệt hạng mục'),
                          ),
                        ),
                        if (item['canEditGuidance'] == true)
                          OutlinedButton(
                            onPressed: () async {
                              final body = await editRecord(
                                context,
                                title: context.tr(
                                  'Execution guidance',
                                  'Hướng dẫn thực hiện',
                                ),
                                initial: {
                                  'description': item['description'],
                                  'executionSteps':
                                      (item['executionSteps'] as List? ?? [])
                                          .join('\n'),
                                  'inputRequirements':
                                      (item['inputRequirements'] as List? ?? [])
                                          .join('\n'),
                                  'expectedOutputs':
                                      (item['expectedOutputs'] as List? ?? [])
                                          .join('\n'),
                                },
                                fields: const [
                                  FieldSpec(
                                    'description',
                                    'Description',
                                    'Mô tả',
                                    kind: FieldKind.multiline,
                                  ),
                                  FieldSpec(
                                    'executionSteps',
                                    'Execution steps (one per line)',
                                    'Các bước (mỗi dòng một bước)',
                                    kind: FieldKind.multiline,
                                  ),
                                  FieldSpec(
                                    'inputRequirements',
                                    'Inputs (one per line)',
                                    'Đầu vào (mỗi dòng một mục)',
                                    kind: FieldKind.multiline,
                                  ),
                                  FieldSpec(
                                    'expectedOutputs',
                                    'Outputs (one per line)',
                                    'Đầu ra (mỗi dòng một mục)',
                                    kind: FieldKind.multiline,
                                  ),
                                  FieldSpec(
                                    'confirm',
                                    'Confirm this guidance',
                                    'Xác nhận hướng dẫn',
                                    kind: FieldKind.toggle,
                                  ),
                                ],
                              );
                              if (body == null || !context.mounted) return;
                              for (final key in [
                                'executionSteps',
                                'inputRequirements',
                                'expectedOutputs',
                              ]) {
                                body[key] = '${body[key]}'
                                    .split('\n')
                                    .map((s) => s.trim())
                                    .where((s) => s.isNotEmpty)
                                    .toList();
                              }
                              if (await runAction(
                                context,
                                () => api.request(
                                  '$path/checklist-items/${segment('${item['id']}')}/guidance',
                                  method: 'PUT',
                                  body: {
                                    ...body,
                                    'expectedChecklistRevision':
                                        pricing['checklistRevision'],
                                    'expectedGuidanceVersion':
                                        item['guidanceVersion'] ?? 0,
                                  },
                                ),
                              )) {
                                reload();
                              }
                            },
                            child: Text(
                              context.tr(
                                'Execution guidance',
                                'Hướng dẫn thực hiện',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              DetailFields(
                data: quote,
                fields: const {
                  'status': ('Quote status', 'Trạng thái báo giá'),
                  'totalAmount': ('Quote total (VND)', 'Tổng báo giá (VND)'),
                },
              ),
              FilledButton(
                onPressed: () async {
                  final items = records(pricing['checklistItems'])
                      .where((item) => item['reviewStatus'] == 'ADDITIONAL')
                      .toList();
                  final body = await editRecord(
                    context,
                    title: context.tr('Draft quote', 'Soạn báo giá'),
                    initial: {
                      'packagePrice':
                          quote['packagePrice'] ?? pricing['basePackagePrice'],
                      'discountAmount': quote['discountAmount'] ?? 0,
                      'adjustmentAmount': quote['adjustmentAmount'] ?? 0,
                      'managerNote': quote['managerNote'],
                      for (final item in items)
                        'price_${item['id']}':
                            item['managerQuotedPrice'] ??
                            item['systemCalculatedPrice'],
                    },
                    fields: [
                      const FieldSpec(
                        'packagePrice',
                        'Package price (VND)',
                        'Giá gói (VND)',
                        kind: FieldKind.number,
                        min: 0,
                      ),
                      const FieldSpec(
                        'discountAmount',
                        'Discount (VND)',
                        'Giảm giá (VND)',
                        kind: FieldKind.number,
                        min: 0,
                      ),
                      const FieldSpec(
                        'adjustmentAmount',
                        'Adjustment (VND)',
                        'Điều chỉnh (VND)',
                        kind: FieldKind.number,
                      ),
                      const FieldSpec(
                        'adjustmentReason',
                        'Adjustment reason',
                        'Lý do điều chỉnh',
                        kind: FieldKind.multiline,
                        required: false,
                      ),
                      const FieldSpec(
                        'adjustmentType',
                        'Adjustment type',
                        'Loại điều chỉnh',
                        kind: FieldKind.choice,
                        required: false,
                        options: {
                          'DISCOUNT': 'Discount / Giảm giá',
                          'PROMOTION': 'Promotion / Khuyến mãi',
                          'COMPENSATION': 'Compensation / Bồi thường',
                          'GOODWILL': 'Goodwill / Thiện chí',
                          'CORRECTION': 'Correction / Sửa sai',
                        },
                      ),
                      const FieldSpec(
                        'managerNote',
                        'Note',
                        'Ghi chú',
                        kind: FieldKind.multiline,
                        required: false,
                      ),
                      for (final item in items) ...[
                        FieldSpec(
                          'price_${item['id']}',
                          '${item['content']} (VND)',
                          '${item['content']} (VND)',
                          kind: FieldKind.number,
                          min: 0,
                        ),
                        FieldSpec(
                          'reason_${item['id']}',
                          'Price reason: ${item['content']}',
                          'Lý do giá: ${item['content']}',
                          kind: FieldKind.multiline,
                          required: false,
                        ),
                      ],
                    ],
                  );
                  if (body == null || !context.mounted) return;
                  final prices = {
                    for (final item in items)
                      '${item['id']}': body.remove('price_${item['id']}'),
                  };
                  final reasons = {
                    for (final item in items)
                      '${item['id']}':
                          body.remove('reason_${item['id']}') ?? '',
                  };
                  if (await runAction(
                    context,
                    () => api.request(
                      '$path/quotes/draft',
                      method: 'PUT',
                      body: {
                        ...body,
                        'additionalUnitPrices': prices,
                        'additionalUnitPriceReasons': reasons,
                        'expectedPricingRevision': quote['pricingRevision'],
                        'expectedPolicyVersion': calculation['policyVersion'],
                        'expectedChecklistRevision':
                            pricing['checklistRevision'],
                      },
                    ),
                  )) {
                    reload();
                  }
                },
                child: Text(context.tr('Edit draft quote', 'Soạn báo giá')),
              ),
              if (['DRAFT', 'PENDING_REVIEW'].contains(quote['status']))
                FilledButton(
                  onPressed: () async {
                    if (await runAction(
                      context,
                      () => api.request(
                        '$path/quotes/${segment('${quote['id']}')}/approve',
                        method: 'POST',
                      ),
                    )) {
                      reload();
                    }
                  },
                  child: Text(context.tr('Approve quote', 'Duyệt báo giá')),
                ),
            ],
          );
        },
      ),
    );
  }
}
