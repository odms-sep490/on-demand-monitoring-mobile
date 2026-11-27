import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/mobile_ui.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../customer/contract_page.dart';
import '../customer/finance_page.dart';
import '../customer/order_actions.dart';
import '../customer/order_confirmation.dart';
import 'delivery_page.dart';
import 'pricing_page.dart';
import 'readiness_page.dart';

class ManagerOrderWorkspace extends ConsumerWidget {
  const ManagerOrderWorkspace({
    super.key,
    required this.id,
    required this.order,
    required this.reload,
  });

  final String id;
  final Json order;
  final VoidCallback reload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final path = '/api/orders/${segment(id)}';
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          recordTitle(order),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              title: Text(
                context.tr('Order information', 'Thông tin đơn hàng'),
              ),
              children: [
                DetailFields(
                  data: order,
                  fields: const {
                    'orderCode': ('Order number', 'Mã đơn hàng'),
                    'orderStatus': ('Status', 'Trạng thái'),
                    'serviceName': ('Service', 'Dịch vụ'),
                    'description': ('Description', 'Mô tả'),
                    'address': ('Site', 'Địa điểm'),
                    'preferredDateFrom': ('From', 'Từ ngày'),
                    'preferredDateTo': ('To', 'Đến ngày'),
                    'preferredTimeName': ('Time slot', 'Khung giờ'),
                    'siteContactName': ('Site contact', 'Người liên hệ'),
                    'siteContactPhone': ('Phone', 'Điện thoại'),
                    'accessNotes': ('Access notes', 'Lưu ý tiếp cận'),
                    'rejectReason': ('Review note', 'Ý kiến duyệt'),
                    'legalReviewStatus': ('Permit review', 'Duyệt giấy phép'),
                    'recurrenceType': ('Repeat', 'Lặp lại'),
                    'dataRetentionDays': ('Retention (days)', 'Lưu trữ (ngày)'),
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SectionCard(
          child: Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                context.tr('Monitoring checklist', 'Hạng mục giám sát'),
              ),
              subtitle: Text('${records(order['checklistItems']).length}'),
              children: [
                for (final item in records(order['checklistItems']))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.checklist_outlined),
                    title: Text('${item['content'] ?? ''}'),
                    subtitle: Text('${item['requiredEvidenceType'] ?? ''}'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: () => open(FinancePage(orderId: id, manager: true)),
          child: Text(
            context.tr('Quote and payments', 'Báo giá và thanh toán'),
          ),
        ),
        OutlinedButton(
          onPressed: () => open(ContractPage(orderId: id, manager: true)),
          child: Text(context.tr('Contract documents', 'Tài liệu hợp đồng')),
        ),
        OrderActions(order: order, manager: true, reload: reload),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SiteAdvisoryPage(order: order),
            ),
          ),
          icon: const Icon(Icons.cloud_outlined),
          label: Text(
            context.tr(
              'Site and weather assessment',
              'Thời tiết và đánh giá khu vực',
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => open(OrderReadinessPage(orderId: id)),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(context.tr('Order readiness', 'Điều kiện duyệt đơn')),
        ),
        OutlinedButton(
          onPressed: () => open(PricingPage(orderId: id)),
          child: Text(context.tr('Review pricing', 'Duyệt giá')),
        ),
        OutlinedButton(
          onPressed: () => open(ManagerDeliveryPage(orderId: id)),
          child: Text(
            context.tr(
              'Publish and revise results',
              'Bàn giao và chỉnh sửa kết quả',
            ),
          ),
        ),
        if ([
          'PENDING',
          'UNDER_REVIEW',
          'NEEDS_INFO',
        ].contains(order['orderStatus'])) ...[
          if (order['orderStatus'] == 'PENDING')
            OutlinedButton(
              onPressed: () async {
                if (await runAction(
                  context,
                  () => api.request('$path/start-review', method: 'POST'),
                )) {
                  reload();
                }
              },
              child: Text(context.tr('Start review', 'Bắt đầu duyệt')),
            ),
          FilledButton(
            onPressed: order['orderStatus'] != 'UNDER_REVIEW'
                ? null
                : () async {
                    if (await runAction(
                      context,
                      () => api.request('$path/approve', method: 'POST'),
                    )) {
                      reload();
                    }
                  },
            child: Text(context.tr('Approve order', 'Duyệt đơn hàng')),
          ),
          OutlinedButton(
            onPressed: () async {
              final body = await editRecord(
                context,
                title: context.tr('Review decision', 'Quyết định duyệt'),
                fields: const [
                  FieldSpec(
                    'decision',
                    'Decision',
                    'Quyết định',
                    kind: FieldKind.choice,
                    options: {
                      'REJECTED': 'Reject / Từ chối',
                      'NEED_INFO': 'Request information / Yêu cầu bổ sung',
                    },
                  ),
                  FieldSpec(
                    'reason',
                    'Reason',
                    'Lý do',
                    kind: FieldKind.multiline,
                  ),
                ],
              );
              if (body != null &&
                  context.mounted &&
                  await runAction(
                    context,
                    () => api.request(
                      '$path/approval',
                      method: 'POST',
                      body: body,
                    ),
                  )) {
                reload();
              }
            },
            child: Text(
              context.tr(
                'Request information or reject',
                'Yêu cầu bổ sung hoặc từ chối',
              ),
            ),
          ),
        ],
      ],
    );
  }
}
