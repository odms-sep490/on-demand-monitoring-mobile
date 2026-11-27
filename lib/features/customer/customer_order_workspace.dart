import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import 'checklist_editor.dart';
import 'contract_page.dart';
import 'customer_missions_page.dart';
import 'finance_page.dart';
import 'order_actions.dart';
import 'order_confirmation.dart';
import 'order_coverage_map.dart';
import 'order_summary.dart';
import 'results_page.dart';

class CustomerOrderWorkspace extends StatefulWidget {
  const CustomerOrderWorkspace({
    super.key,
    required this.order,
    required this.id,
    required this.reload,
  });
  final Json order;
  final String id;
  final VoidCallback reload;
  @override
  State<CustomerOrderWorkspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<CustomerOrderWorkspace> {
  int active = 0;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final id = widget.id;
    final colors = Theme.of(context).colorScheme;
    Future<void> open(Widget page, {bool refresh = false}) async {
      await Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => page));
      if (refresh && mounted) widget.reload();
    }

    Widget action(IconData icon, String label, VoidCallback onTap) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: colors.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
    final panels = [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderCoverageMap(order: order),
          OrderProgress(status: recordStatus(order)),
          OrderActions(order: order, manager: false, reload: widget.reload),
          Text(
            context.tr('Order information', 'Thông tin đơn hàng'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Divider(),
          DetailFields(
            data: order,
            fields: const {
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
          action(
            Icons.cloud_outlined,
            context.tr(
              'Site and weather assessment',
              'Thời tiết và đánh giá khu vực',
            ),
            () => open(SiteAdvisoryPage(order: order)),
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Monitoring checklist', 'Hạng mục giám sát'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Divider(),
          for (final (index, item) in records(order['checklistItems']).indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text('${item['content'] ?? ''}'),
              subtitle: Text('${item['requiredEvidenceType'] ?? ''}'),
            ),
          if (order['canEditChecklist'] == true)
            action(
              Icons.edit_note,
              context.tr('Edit checklist', 'Chỉnh sửa hạng mục'),
              () => open(CustomerChecklistEditor(order: order), refresh: true),
            ),
          action(
            Icons.assignment_outlined,
            context.tr('Missions and reports', 'Nhiệm vụ và báo cáo'),
            () => open(CustomerMissionsPage(orderId: id)),
          ),
        ],
      ),
      Column(
        children: [
          action(
            Icons.receipt_long_outlined,
            context.tr('Quotes and payments', 'Báo giá và thanh toán'),
            () => open(FinancePage(orderId: id), refresh: true),
          ),
          const Divider(height: 1),
          action(
            Icons.description_outlined,
            context.tr('Contract documents', 'Tài liệu hợp đồng'),
            () =>
                open(ContractPage(orderId: id, manager: false), refresh: true),
          ),
        ],
      ),
      Column(
        children: [
          action(
            Icons.photo_library_outlined,
            context.tr('Delivered results', 'Kết quả bàn giao'),
            () => open(ResultsPage(orderId: id), refresh: true),
          ),
          const Divider(height: 1),
          action(
            Icons.assignment_outlined,
            context.tr('Missions and reports', 'Nhiệm vụ và báo cáo'),
            () => open(CustomerMissionsPage(orderId: id)),
          ),
        ],
      ),
    ];
    final tabs = [
      (Icons.dashboard_outlined, context.tr('Overview', 'Tổng quan')),
      (Icons.checklist_outlined, context.tr('Monitoring', 'Giám sát')),
      (Icons.receipt_long_outlined, context.tr('Finance', 'Tài chính')),
      (Icons.inventory_2_outlined, context.tr('Results', 'Kết quả')),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CustomerOrderHeader(order: order),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (index, tab) in tabs.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(tab.$1, size: 17),
                    label: Text(tab.$2),
                    selected: active == index,
                    onSelected: (_) => setState(() => active = index),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: KeyedSubtree(key: ValueKey(active), child: panels[active]),
        ),
      ],
    );
  }
}
