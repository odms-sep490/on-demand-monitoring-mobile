import '../../shared/portal_scaffold.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import 'finance_page.dart';
import 'order_actions.dart';
import 'order_confirmation.dart';
import 'checklist_editor.dart';
import '../manager/pricing_page.dart';
import '../manager/readiness_page.dart';
import '../manager/delivery_page.dart';
import 'contract_page.dart';
import 'results_page.dart';

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.id, required this.manager});
  final String id;
  final bool manager;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider), path = '/api/orders/${segment(id)}';
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Order details', 'Chi tiết đơn hàng')),
      ),
      body: RemoteView(
        load: () => api.request(path),
        builder: (context, value, reload) {
          final order = object(value);
          void open(Widget page) => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => page),
          );
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                recordTitle(order),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
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
              for (final item in records(order['checklistItems']))
                Card(
                  child: ListTile(
                    title: Text('${item['content'] ?? ''}'),
                    subtitle: Text('${item['requiredEvidenceType'] ?? ''}'),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () =>
                    open(FinancePage(orderId: id, manager: manager)),
                child: Text(
                  context.tr('Quote and payments', 'Báo giá và thanh toán'),
                ),
              ),
              OutlinedButton(
                onPressed: () =>
                    open(ContractPage(orderId: id, manager: manager)),
                child: Text(
                  context.tr('Contract documents', 'Tài liệu hợp đồng'),
                ),
              ),
              OrderActions(order: order, manager: manager, reload: reload),
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
              if (!manager && order['canEditChecklist'] == true)
                OutlinedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CustomerChecklistEditor(order: order),
                      ),
                    );
                    reload();
                  },
                  child: Text(
                    context.tr(
                      'Edit monitoring checklist',
                      'Chỉnh sửa hạng mục giám sát',
                    ),
                  ),
                ),
              if (manager) ...[
                OutlinedButton.icon(
                  onPressed: () => open(OrderReadinessPage(orderId: id)),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(
                    context.tr('Order readiness', 'Điều kiện duyệt đơn'),
                  ),
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
              ],
              if (!manager) ...[
                OutlinedButton(
                  onPressed: () => open(CustomerMissionsPage(orderId: id)),
                  child: Text(
                    context.tr('Missions and reports', 'Nhiệm vụ và báo cáo'),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => open(ResultsPage(orderId: id)),
                  child: Text(
                    context.tr(
                      'Review delivered results',
                      'Đánh giá kết quả bàn giao',
                    ),
                  ),
                ),
              ],
              if (manager &&
                  [
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
                            'NEED_INFO':
                                'Request information / Yêu cầu bổ sung',
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
        },
      ),
    );
  }
}

class CustomerMissionsPage extends ConsumerWidget {
  const CustomerMissionsPage({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        path = '/api/customer/orders/${segment(orderId)}/missions';
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Missions and reports', 'Nhiệm vụ và báo cáo')),
      ),
      body: RemoteView(
        load: () => api.request(path),
        builder: (context, data, reload) => RecordList(
          items: records(data),
          refresh: reload,
          onTap: (mission) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PortalScaffold(
                  appBar: AppBar(title: Text('${mission['missionCode']}')),
                  body: RemoteView(
                    load: () => api.request(
                      '$path/${segment('${mission['missionId']}')}/report',
                    ),
                    builder: (context, data, _) {
                      final report = object(data);
                      return ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          DetailFields(
                            data: object(report['mission']),
                            fields: const {
                              'scopeLabel': ('Scope', 'Phạm vi'),
                              'status': ('Status', 'Trạng thái'),
                              'scheduledStartAt': (
                                'Scheduled start',
                                'Bắt đầu dự kiến',
                              ),
                              'scheduledEndAt': (
                                'Scheduled end',
                                'Kết thúc dự kiến',
                              ),
                            },
                          ),
                          if (report['reportAvailable'] != true)
                            Text(
                              context.tr(
                                'Report is not available yet.',
                                'Báo cáo chưa sẵn sàng.',
                              ),
                            ),
                          DetailFields(
                            data: object(report['result']),
                            fields: const {
                              'summary': ('Summary', 'Tóm tắt'),
                              'completedAt': ('Completed', 'Hoàn thành'),
                            },
                          ),
                          for (final item in records(report['checklistItems']))
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: DetailFields(
                                  data: item,
                                  fields: const {
                                    'content': ('Requirement', 'Yêu cầu'),
                                    'status': ('Status', 'Trạng thái'),
                                    'assessment': ('Assessment', 'Đánh giá'),
                                    'observation': ('Observation', 'Nhận xét'),
                                    'unableToVerifyReason': (
                                      'Unable to verify',
                                      'Không thể xác minh',
                                    ),
                                  },
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
