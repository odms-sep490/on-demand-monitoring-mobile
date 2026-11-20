import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/mobile_ui.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import 'customer_pages.dart' show createOrder;

class CustomerOrdersPage extends ConsumerStatefulWidget {
  const CustomerOrdersPage({super.key});
  @override
  ConsumerState<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends ConsumerState<CustomerOrdersPage> {
  String query = '', status = '';
  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return PortalScaffold(
      appBar: AppBar(title: Text(context.tr('My orders', 'Đơn của tôi'))),
      body: RemoteView(
        load: () => api.request('/api/orders/mine'),
        builder: (context, value, reload) {
          final all = records(value);
          final filtered = all
              .where(
                (item) =>
                    (status.isEmpty || item['orderStatus'] == status) &&
                    '${recordTitle(item)} ${item['orderCode']} ${item['address']} ${item['serviceName']}'
                        .toLowerCase()
                        .contains(query.toLowerCase()),
              )
              .toList();
          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PageIntro(
                  title: context.tr('Monitoring requests', 'Yêu cầu giám sát'),
                  description: context.tr(
                    'Track the status of the monitoring requests you submitted.',
                    'Theo dõi trạng thái các yêu cầu giám sát bạn đã gửi.',
                  ),
                  action: FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(context.tr('New request', 'Tạo yêu cầu')),
                    onPressed: () async {
                      if (await createOrder(context, api)) reload();
                    },
                  ),
                ),
                StatGrid(
                  children: [
                    StatTile(
                      label: context.tr('Total orders', 'Tổng số đơn'),
                      value: '${all.length}',
                      icon: Icons.assignment_outlined,
                    ),
                    StatTile(
                      label: context.tr('Pending', 'Chờ duyệt'),
                      value:
                          '${all.where((e) => e['orderStatus'] == 'PENDING').length}',
                      icon: Icons.hourglass_top,
                      color: const Color(0xFFF59E0B),
                    ),
                    StatTile(
                      label: context.tr('In progress', 'Đang thực hiện'),
                      value:
                          '${all.where((e) => e['orderStatus'] == 'IN_PROGRESS').length}',
                      icon: Icons.radar,
                    ),
                    StatTile(
                      label: context.tr('Completed', 'Hoàn thành'),
                      value:
                          '${all.where((e) => e['orderStatus'] == 'COMPLETED').length}',
                      icon: Icons.task_alt,
                      color: const Color(0xFF16A34A),
                    ),
                  ],
                ),
                SectionCard(
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        isExpanded: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.filter_list, size: 18),
                          labelText: context.tr('Status', 'Trạng thái'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(
                              context.tr('All statuses', 'Tất cả trạng thái'),
                            ),
                          ),
                          for (final value in [
                            'PENDING',
                            'UNDER_REVIEW',
                            'NEEDS_INFO',
                            'APPROVED',
                            'IN_PROGRESS',
                            'COMPLETED',
                            'REJECTED',
                            'CANCELLED',
                          ])
                            DropdownMenuItem(
                              value: value,
                              child: Text(statusText(context, value)),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => status = value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 20),
                          hintText: context.tr(
                            'Search title, location, service…',
                            'Tìm theo tiêu đề, địa điểm, dịch vụ…',
                          ),
                        ),
                        onChanged: (value) => setState(() => query = value),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        context.tr('Orders', 'Đơn hàng'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        '${filtered.length}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                if (filtered.isEmpty)
                  SectionCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            size: 40,
                            color: odmsMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr(
                              'No matching orders.',
                              'Chưa có đơn hàng phù hợp.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final item in filtered)
                  DomainCard(
                    item: item,
                    onTap: () async {
                      await context.push(
                        '/customer/orders/${segment('${item['id']}')}',
                      );
                      reload();
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}
