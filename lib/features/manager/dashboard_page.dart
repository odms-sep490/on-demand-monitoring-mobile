import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/mobile_ui.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class ManagerDashboardPage extends ConsumerStatefulWidget {
  const ManagerDashboardPage({super.key});
  @override
  ConsumerState<ManagerDashboardPage> createState() =>
      _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends ConsumerState<ManagerDashboardPage> {
  String range = '30D';
  @override
  Widget build(BuildContext context) => PortalScaffold(
    appBar: AppBar(title: Text(context.tr('Overview', 'Tổng quan'))),
    body: RemoteView(
      key: ValueKey(range),
      load: () => ref
          .read(apiProvider)
          .request('/api/manager/dashboard', query: {'range': range}),
      builder: (context, value, reload) {
        final data = object(value),
            summary = object(object(value)['summary']),
            pipeline = object(object(value)['pricingPipeline']),
            overview = object(object(value)['missionOverview']);
        String number(Object? value) => value is num
            ? MaterialLocalizations.of(context).formatDecimal(value.toInt())
            : '—';
        Widget kpi(
          String en,
          String vi,
          Object? value,
          IconData icon,
          Color color,
        ) => StatTile(
          label: context.tr(en, vi),
          value: number(value),
          icon: icon,
          color: color,
        );
        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageIntro(
                title: context.tr(
                  'Operational overview',
                  'Tổng quan điều hành',
                ),
                eyebrow: MaterialLocalizations.of(context)
                    .formatFullDate(DateTime.now()),
                description: context.tr(
                  'Review orders, coordinate missions and keep work moving.',
                  'Duyệt yêu cầu, điều phối nhiệm vụ và theo dõi công việc.',
                ),
                action: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => context.go('/manager/orders'),
                        icon: const Icon(Icons.fact_check_outlined, size: 18),
                        label: Text(
                          context.tr('Review orders', 'Duyệt đơn hàng'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go('/manager/missions'),
                            child: Text(context.tr('Missions', 'Nhiệm vụ')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.go('/manager/schedule'),
                            child: Text(
                              context.tr('Schedule', 'Lịch nhiệm vụ'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        for (final day in ['7', '30', '90'])
                          ButtonSegment(
                            value: '${day}D',
                            label: Text(context.tr('$day days', '$day ngày')),
                          ),
                      ],
                      selected: {range},
                      onSelectionChanged: (value) =>
                          setState(() => range = value.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: reload,
                    tooltip: context.tr('Refresh', 'Làm mới'),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              StatGrid(
                children: [
                  kpi(
                    'Awaiting review',
                    'Chờ duyệt',
                    summary['pendingOrderCount'] ??
                        object(object(data['kpis'])['pendingOrders'])['count'],
                    Icons.fact_check_outlined,
                    odmsBlue,
                  ),
                  kpi(
                    'Pricing review',
                    'Chờ báo giá',
                    pipeline['pricingReviewCount'],
                    Icons.request_quote_outlined,
                    const Color(0xFF8B5CF6),
                  ),
                  kpi(
                    'Awaiting deposit',
                    'Chờ đặt cọc',
                    summary['waitingDepositCount'],
                    Icons.account_balance_wallet_outlined,
                    const Color(0xFFF59E0B),
                  ),
                  kpi(
                    'Active missions',
                    'Đang thực hiện',
                    summary['activeMissionCount'],
                    Icons.radar,
                    const Color(0xFF16A34A),
                  ),
                  kpi(
                    'Total orders',
                    'Tổng đơn hàng',
                    summary['totalOrders'],
                    Icons.assignment_outlined,
                    odmsBlue,
                  ),
                  kpi(
                    'Needs attention',
                    'Cần xử lý',
                    summary['attentionRequiredCount'],
                    Icons.priority_high,
                    const Color(0xFFDC2626),
                  ),
                ],
              ),
              SectionCard(
                title: context.tr('Action items', 'Việc cần làm'),
                trailing: CircleAvatar(
                  radius: 12,
                  backgroundColor: odmsBlue,
                  child: Text(
                    '${records(data['actionItems']).length}',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
                child: Column(
                  children: [
                    if (records(data['actionItems']).isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          context.tr(
                            'You are up to date.',
                            'Không có công việc cần xử lý.',
                          ),
                        ),
                      ),
                    for (final item in records(data['actionItems']))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: InkWell(
                          onTap: () {
                            if (item['orderId'] != null) {
                              context.push(
                                '/manager/orders/${segment('${item['orderId']}')}',
                              );
                            } else if (item['missionId'] != null) {
                              context.push(
                                '/manager/missions/${segment('${item['missionId']}')}',
                              );
                            }
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(
                                  top: 6,
                                  right: 10,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDC2626),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['title']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    if (item['description'] != null)
                                      Text(
                                        '${item['description']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SectionCard(
                title: context.tr('Mission status', 'Trạng thái nhiệm vụ'),
                trailing: TextButton(
                  onPressed: () => context.go('/manager/missions'),
                  child: Text(context.tr('View all', 'Xem tất cả')),
                ),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 16,
                  children: [
                    for (final entry in {
                      'scheduledCount': ('Scheduled', 'Đã lên lịch'),
                      'readyCount': ('Ready', 'Sẵn sàng'),
                      'inFlightCount': ('In flight', 'Đang bay'),
                      'returningCount': ('Returning', 'Đang trở về'),
                      'completedTodayCount': (
                        'Completed today',
                        'Hoàn thành hôm nay',
                      ),
                      'issueCount': ('Needs attention', 'Cần xử lý'),
                    }.entries)
                      SizedBox(
                        width: 130,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.tr(entry.value.$1, entry.value.$2),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Text(
                              number(overview[entry.key]),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (records(data['activeMissions']).isNotEmpty)
                SectionCard(
                  title: context.tr(
                    'Missions being monitored',
                    'Nhiệm vụ đang theo dõi',
                  ),
                  child: Column(
                    children: [
                      for (final mission in records(data['activeMissions']))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${mission['missionCode']}'),
                          subtitle: Text(
                            '${mission['operatorName'] ?? ''} · ${mission['status']}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(
                            '/manager/missions/${segment('${mission['missionId']}')}',
                          ),
                        ),
                    ],
                  ),
                ),
              DistributionBars(
                title: context.tr(
                  'Missions over time',
                  'Nhiệm vụ theo thời gian',
                ),
                items: [
                  for (final point in records(data['missionTrend']))
                    {
                      'label': '${point['periodStart']}',
                      'count':
                          (point['completed'] as num? ?? 0) +
                          (point['failed'] as num? ?? 0),
                    },
                ],
                labelKey: 'label',
              ),
              SectionCard(
                title: context.tr('Recent orders', 'Đơn gần đây'),
                trailing: TextButton(
                  onPressed: () => context.go('/manager/orders'),
                  child: Text(context.tr('View all', 'Xem tất cả')),
                ),
                child: Column(
                  children: [
                    if (records(data['recentOrders']).isEmpty)
                      Text(
                        context.tr('No recent orders.', 'Chưa có đơn gần đây.'),
                      ),
                    for (final order in records(data['recentOrders']))
                      DomainCard(
                        item: {
                          ...order,
                          'title': order['orderCode'],
                          'orderStatus': order['status'],
                        },
                        showCustomer: true,
                        onTap: () => context.push(
                          '/manager/orders/${segment('${order['orderId']}')}',
                        ),
                      ),
                  ],
                ),
              ),
              DistributionBars(
                title: context.tr('Quotation pipeline', 'Tiến trình báo giá'),
                items: [
                  for (final entry in {
                    'pricingReviewCount': ('Pricing review', 'Chờ duyệt giá'),
                    'quoteReadyCount': ('Quote ready', 'Sẵn sàng báo giá'),
                    'waitingCustomerCount': (
                      'Waiting for customer',
                      'Chờ khách hàng',
                    ),
                    'waitingDepositCount': ('Awaiting deposit', 'Chờ đặt cọc'),
                    'depositPaidCount': ('Deposit paid', 'Đã đặt cọc'),
                  }.entries)
                    {
                      'label': context.tr(entry.value.$1, entry.value.$2),
                      'count': pipeline[entry.key] ?? 0,
                    },
                ],
                labelKey: 'label',
              ),
              SectionCard(
                title: context.tr('Recent activity', 'Hoạt động gần đây'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (records(data['recentActivities']).isEmpty)
                      Text(
                        context.tr(
                          'No recent activity.',
                          'Chưa có hoạt động gần đây.',
                        ),
                      ),
                    for (final activity in records(data['recentActivities']))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${activity['occurredAt']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 5),
                            Text('${activity['description']}'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              DistributionBars(
                title: context.tr('Order status', 'Trạng thái đơn hàng'),
                items: [
                  for (final item in records(data['orderStatusDistribution']))
                    {...item, 'label': statusText(context, '${item['key']}')},
                ],
                labelKey: 'label',
              ),
              DistributionBars(
                title: context.tr('Requested services', 'Dịch vụ được yêu cầu'),
                items: records(data['serviceDistribution']),
                labelKey: 'serviceName',
              ),
              DistributionBars(
                title: context.tr('Mission distribution', 'Phân bổ nhiệm vụ'),
                items: [
                  for (final item in records(data['missionStatusDistribution']))
                    {...item, 'label': statusText(context, '${item['key']}')},
                ],
                labelKey: 'label',
              ),
            ],
          ),
        );
      },
    ),
  );
}

class DistributionBars extends StatelessWidget {
  const DistributionBars({
    super.key,
    required this.title,
    required this.items,
    required this.labelKey,
  });
  final String title, labelKey;
  final List<Json> items;
  @override
  Widget build(BuildContext context) {
    final max = items.fold<num>(
      0,
      (max, item) =>
          (item['count'] as num? ?? 0) > max ? item['count'] as num : max,
    );
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                context.tr(
                  'No data for this period.',
                  'Chưa có dữ liệu trong kỳ này.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item[labelKey]}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${item['count'] ?? 0}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: max == 0
                          ? 0
                          : ((item['count'] as num? ?? 0) / max)
                                .clamp(0, 1)
                                .toDouble(),
                      minHeight: 6,
                      backgroundColor: odmsBlue.withValues(alpha: .06),
                      color: odmsBlue,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
