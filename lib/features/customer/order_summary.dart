import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../shared/mobile_ui.dart';
import '../../shared/strings.dart';

class CustomerOrderHeader extends StatelessWidget {
  const CustomerOrderHeader({super.key, required this.order});
  final Json order;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = recordStatus(order);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/construction-640.webp'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0C2141), Color(0xD6123C6B)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order['orderCode'] != null)
                Text(
                  '${order['orderCode']}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFFB7DEFF),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                recordTitle(order),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              if (order['address'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${order['address']}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFE4F1FF),
                  ),
                ),
              ],
              if (status.isNotEmpty) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: StatusPill(status: status),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OrderProgress extends StatelessWidget {
  const OrderProgress({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final stage = switch (status) {
      'PENDING' || 'UNDER_REVIEW' || 'NEEDS_INFO' => 1,
      'APPROVED' || 'IN_PROGRESS' => 2,
      'COMPLETED' => 3,
      _ => null,
    };
    if (stage == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final phases = [
      context.tr('Request received', 'Đã tiếp nhận'),
      context.tr('Order review', 'Duyệt đơn'),
      context.tr('Monitoring', 'Giám sát'),
      context.tr('Monitoring complete', 'Hoàn thành giám sát'),
    ];
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Order progress', 'Tiến độ đơn'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final (index, label) in phases.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(
                    index < stage
                        ? Icons.check_circle
                        : index == stage
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 19,
                    color: index <= stage ? colors.primary : colors.outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: index == stage
                          ? Theme.of(context).textTheme.titleSmall
                          : null,
                    ),
                  ),
                  if (index == stage)
                    Text(
                      context.tr('Current', 'Hiện tại'),
                      style: TextStyle(color: colors.primary),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
