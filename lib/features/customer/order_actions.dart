import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/area_picker.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class OrderActions extends ConsumerWidget {
  const OrderActions({
    super.key,
    required this.order,
    required this.manager,
    required this.reload,
  });
  final Json order;
  final bool manager;
  final VoidCallback reload;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        path = '/api/orders/${segment('${order['id']}')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (manager && order['orderStatus'] == 'UNDER_REVIEW')
          OutlinedButton(
            onPressed: () async {
              final body = await editRecord(
                context,
                title: context.tr(
                  'Area and permit review',
                  'Duyệt khu vực và giấy phép',
                ),
                fields: const [
                  FieldSpec(
                    'status',
                    'Decision',
                    'Quyết định',
                    kind: FieldKind.choice,
                    options: {
                      'NOT_REQUIRED':
                          'Permit not required / Không cần giấy phép',
                      'PENDING_PERMIT': 'Pending permit / Chờ giấy phép',
                      'REJECTED': 'Area unsuitable / Khu vực không phù hợp',
                    },
                  ),
                  FieldSpec(
                    'requestedScopeFeasible',
                    'Requested scope feasible?',
                    'Phạm vi yêu cầu khả thi?',
                    kind: FieldKind.choice,
                    options: {'true': 'Yes / Có', 'false': 'No / Không'},
                  ),
                  FieldSpec(
                    'reason',
                    'Reason',
                    'Lý do',
                    kind: FieldKind.multiline,
                    required: false,
                  ),
                  FieldSpec(
                    'note',
                    'Note',
                    'Ghi chú',
                    kind: FieldKind.multiline,
                    required: false,
                  ),
                ],
              );
              if (body == null || !context.mounted) return;
              body['requestedScopeFeasible'] =
                  body['requestedScopeFeasible'] == 'true';
              if (await runAction(
                context,
                () => api.request(
                  '$path/flight-area-review',
                  method: 'POST',
                  body: body,
                ),
              )) {
                reload();
              }
            },
            child: Text(
              context.tr(
                'Review area and permit',
                'Duyệt khu vực và giấy phép',
              ),
            ),
          ),
        if (manager && order['legalReviewStatus'] == 'PENDING_PERMIT')
          OutlinedButton(
            onPressed: () async {
              final body = await editRecord(
                context,
                title: context.tr(
                  'Resolve permit review',
                  'Kết quả xác minh giấy phép',
                ),
                fields: const [
                  FieldSpec(
                    'status',
                    'Permit verification',
                    'Xác minh giấy phép',
                    kind: FieldKind.choice,
                    options: {
                      'APPROVED': 'Approved / Được duyệt',
                      'REJECTED': 'Rejected / Từ chối',
                    },
                  ),
                  FieldSpec(
                    'note',
                    'Verification note',
                    'Ghi chú xác minh',
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
                      '$path/legal-review/resolve',
                      method: 'POST',
                      body: body,
                    ),
                  )) {
                reload();
              }
            },
            child: Text(
              context.tr('Resolve permit review', 'Xác minh giấy phép'),
            ),
          ),
        if (!manager && order['orderStatus'] == 'PENDING')
          OutlinedButton(
            onPressed: () async {
              final body = await editRecord(
                context,
                title: context.tr('Edit request', 'Chỉnh sửa yêu cầu'),
                initial: order,
                fields: const [
                  FieldSpec('title', 'Title', 'Tiêu đề'),
                  FieldSpec(
                    'description',
                    'Description',
                    'Mô tả',
                    kind: FieldKind.multiline,
                    required: false,
                  ),
                  FieldSpec('address', 'Site address', 'Địa chỉ giám sát'),
                  FieldSpec(
                    'siteContactName',
                    'Site contact',
                    'Người liên hệ',
                    required: false,
                  ),
                  FieldSpec(
                    'siteContactPhone',
                    'Contact phone',
                    'Số điện thoại',
                    required: false,
                  ),
                  FieldSpec(
                    'accessNotes',
                    'Access notes',
                    'Lưu ý tiếp cận',
                    kind: FieldKind.multiline,
                    required: false,
                  ),
                ],
              );
              if (body != null &&
                  context.mounted &&
                  await runAction(
                    context,
                    () => api.request(path, method: 'PATCH', body: body),
                  )) {
                reload();
              }
            },
            child: Text(context.tr('Edit request', 'Chỉnh sửa yêu cầu')),
          ),
        if (!manager &&
            order['orderStatus'] == 'NEEDS_INFO' &&
            order['requestedUpdateScope'] != 'LOCATION')
          FilledButton(
            onPressed: () async {
              final body = await editRecord(
                context,
                title: context.tr(
                  'Provide requested information',
                  'Bổ sung thông tin',
                ),
                initial: order,
                fields: const [
                  FieldSpec(
                    'information',
                    'Additional information',
                    'Thông tin bổ sung',
                    kind: FieldKind.multiline,
                  ),
                  FieldSpec(
                    'siteContactName',
                    'Site contact',
                    'Người liên hệ',
                    required: false,
                  ),
                  FieldSpec(
                    'siteContactPhone',
                    'Contact phone',
                    'Số điện thoại',
                    required: false,
                  ),
                  FieldSpec(
                    'accessNotes',
                    'Access notes',
                    'Lưu ý tiếp cận',
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
                      '$path/additional-information',
                      method: 'POST',
                      body: body,
                    ),
                  )) {
                reload();
              }
            },
            child: Text(
              context.tr('Provide requested information', 'Bổ sung thông tin'),
            ),
          ),
        if (!manager &&
            (order['orderStatus'] == 'PENDING' ||
                order['orderStatus'] == 'NEEDS_INFO' &&
                    order['requestedUpdateScope'] == 'LOCATION'))
          OutlinedButton(
            onPressed: () async {
              final area = await Navigator.push<Json>(
                context,
                MaterialPageRoute(builder: (_) => const AreaPicker()),
              );
              if (area != null &&
                  context.mounted &&
                  await runAction(
                    context,
                    () => api.request(path, method: 'PATCH', body: area),
                  )) {
                reload();
              }
            },
            child: Text(
              context.tr(
                'Correct monitoring area',
                'Chỉnh sửa khu vực giám sát',
              ),
            ),
          ),
      ],
    );
  }
}
