import 'package:material_ui/material_ui.dart';

import '../core/models.dart';
import 'strings.dart';

const odmsBlue = Color(0xFF1565E8);
const odmsInk = Color(0xFF0F1B3D);
const odmsMuted = Color(0xFF64748B);
String displayDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final date = value.contains('T')
      ? parsed.toUtc().add(const Duration(hours: 7))
      : parsed;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}${value.contains('T') ? ' · ${two(date.hour)}:${two(date.minute)}' : ''}';
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).dividerColor),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080F1B3D),
          offset: Offset(0, 3),
          blurRadius: 12,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        Padding(padding: padding, child: child),
      ],
    ),
  );
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.title,
    this.description,
    this.action,
    this.eyebrow,
  });
  final String title;
  final String? description, eyebrow;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Theme.of(context).dividerColor),
      gradient: LinearGradient(
        colors: Theme.of(context).brightness == Brightness.dark
            ? const [Color(0xFF162B50), Color(0xFF111B36)]
            : const [Color(0xFFEDF5FF), Color(0xFFFFFFFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: odmsMuted),
          ),
          const SizedBox(height: 8),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    ),
  );
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = odmsBlue,
    this.note,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  final String? note;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(note!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}

class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth > 650 ? 4 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        ),
      );
    },
  );
}

String statusText(BuildContext context, String status) {
  final labels = <String, (String, String)>{
    'PENDING': ('Pending', 'Chờ duyệt'),
    'UNDER_REVIEW': ('Under review', 'Đang duyệt'),
    'NEEDS_INFO': ('Needs information', 'Cần bổ sung'),
    'APPROVED': ('Approved', 'Đã duyệt'),
    'REJECTED': ('Rejected', 'Từ chối'),
    'IN_PROGRESS': ('In progress', 'Đang thực hiện'),
    'COMPLETED': ('Completed', 'Hoàn thành'),
    'CANCELLED': ('Cancelled', 'Đã hủy'),
    'FAILED': ('Failed', 'Không thành công'),
    'PLANNING': ('Planning', 'Lập kế hoạch'),
    'PENDING_PAYMENT': ('Awaiting payment', 'Chờ thanh toán'),
    'PENDING_CONFIRMATION': ('Awaiting confirmation', 'Chờ xác nhận'),
    'READY': ('Ready', 'Sẵn sàng'),
    'AWAITING_REVIEW': ('Awaiting review', 'Chờ duyệt kết quả'),
    'PENDING_REVIEW': ('Awaiting review', 'Chờ duyệt'),
    'OPEN': ('Open', 'Mới'),
    'ASSIGNED': ('Assigned', 'Đã phân công'),
    'RESOLVED': ('Resolved', 'Đã xử lý'),
    'CLOSED': ('Closed', 'Đã đóng'),
    'AVAILABLE': ('Available', 'Sẵn sàng'),
    'RESERVED': ('Reserved', 'Đã đặt'),
    'MAINTENANCE': ('Maintenance', 'Bảo trì'),
    'OUT_OF_SERVICE': ('Out of service', 'Ngừng hoạt động'),
    'WAITING_FOR_CUSTOMER': ('Waiting for customer', 'Chờ khách hàng'),
    'WAITING_FOR_STAFF': ('Waiting for staff', 'Chờ nhân viên'),
  };
  final label = labels[status];
  return label == null
      ? status.replaceAll('_', ' ')
      : context.tr(label.$1, label.$2);
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color =
        ['COMPLETED', 'RESOLVED', 'AVAILABLE', 'CLOSED'].contains(status)
        ? const Color(0xFF16A34A)
        : ['REJECTED', 'FAILED', 'CANCELLED', 'OUT_OF_SERVICE'].contains(status)
        ? const Color(0xFFDC2626)
        : [
            'PENDING',
            'NEEDS_INFO',
            'PENDING_PAYMENT',
            'MAINTENANCE',
          ].contains(status)
        ? const Color(0xFFD97706)
        : odmsBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              statusText(context, status),
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MetaLine extends StatelessWidget {
  const MetaLine({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: odmsMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class DomainCard extends StatelessWidget {
  const DomainCard({
    super.key,
    required this.item,
    this.onTap,
    this.showCustomer = false,
  });
  final Json item;
  final VoidCallback? onTap;
  final bool showCustomer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      recordTitle(item),
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(height: 1.45),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (recordStatus(item).isNotEmpty)
                    Flexible(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: StatusPill(status: recordStatus(item)),
                      ),
                    ),
                ],
              ),
              if ((item['orderCode'] ??
                      item['missionCode'] ??
                      item['ticketCode']) !=
                  null)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '${item['orderCode'] ?? item['missionCode'] ?? item['ticketCode']}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: odmsMuted),
                  ),
                ),
              if (showCustomer && item['customerName'] != null)
                MetaLine(
                  icon: Icons.person_outline,
                  text: '${item['customerName']}',
                ),
              if (item['serviceName'] != null)
                MetaLine(
                  icon: Icons.layers_outlined,
                  text: '${item['serviceName']}',
                ),
              if (item['address'] != null)
                MetaLine(
                  icon: Icons.place_outlined,
                  text: '${item['address']}',
                ),
              if ((item['scheduledStartAt'] ??
                      item['preferredDateFrom'] ??
                      item['date']) !=
                  null)
                MetaLine(
                  icon: Icons.schedule,
                  text:
                      displayDate(
                        '${item['scheduledStartAt'] ?? item['preferredDateFrom'] ?? item['date']}',
                      ) +
                      (item['preferredTimeName'] == null
                          ? ''
                          : ' · ${item['preferredTimeName']}'),
                ),
              if (onTap != null) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      context.tr('View details', 'Xem chi tiết'),
                      style: const TextStyle(
                        color: odmsBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward, color: odmsBlue, size: 17),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
