import '../../shared/portal_scaffold.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../shared/coverage_geometry.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../../shared/mobile_ui.dart';
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
          if (!manager) {
            return _CustomerOrderWorkspace(
              key: ValueKey(id),
              order: order,
              id: id,
              reload: reload,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (manager)
                Text(
                  recordTitle(order),
                  style: Theme.of(context).textTheme.headlineSmall,
                )
              else
                _CustomerOrderHeader(order: order),
              if (!manager) ...[
                const SizedBox(height: 12),
                _OrderProgress(status: recordStatus(order)),
              ],
              const SizedBox(height: 16),
              SectionCard(
                child: Material(
                  type: MaterialType.transparency,
                  child: ExpansionTile(
                    initiallyExpanded: manager,
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
                          'legalReviewStatus': (
                            'Permit review',
                            'Duyệt giấy phép',
                          ),
                          'recurrenceType': ('Repeat', 'Lặp lại'),
                          'dataRetentionDays': (
                            'Retention (days)',
                            'Lưu trữ (ngày)',
                          ),
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
                    subtitle: Text(
                      '${records(order['checklistItems']).length}',
                    ),
                    children: [
                      for (final item in records(order['checklistItems']))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.checklist_outlined),
                          title: Text('${item['content'] ?? ''}'),
                          subtitle: Text(
                            '${item['requiredEvidenceType'] ?? ''}',
                          ),
                        ),
                    ],
                  ),
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

class _CustomerOrderHeader extends StatelessWidget {
  const _CustomerOrderHeader({required this.order});
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

class _OrderProgress extends StatelessWidget {
  const _OrderProgress({required this.status});
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

class _CustomerOrderWorkspace extends StatefulWidget {
  const _CustomerOrderWorkspace({
    super.key,
    required this.order,
    required this.id,
    required this.reload,
  });
  final Json order;
  final String id;
  final VoidCallback reload;
  @override
  State<_CustomerOrderWorkspace> createState() =>
      _CustomerOrderWorkspaceState();
}

class _CustomerOrderWorkspaceState extends State<_CustomerOrderWorkspace> {
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
          _OrderCoverageMap(order: order),
          _OrderProgress(status: recordStatus(order)),
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
        _CustomerOrderHeader(order: order),
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

class _OrderCoverageMap extends StatefulWidget {
  const _OrderCoverageMap({required this.order});
  final Json order;
  @override
  State<_OrderCoverageMap> createState() => _OrderCoverageMapState();
}

class _OrderCoverageMapState extends State<_OrderCoverageMap> {
  bool satellite = false;
  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final lat = num.tryParse('${order['latitude']}')?.toDouble();
    final lon = num.tryParse('${order['longitude']}')?.toDouble();
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      return const SizedBox.shrink();
    }
    final center = LatLng(lat, lon);
    final geometry = object(order['coverageArea']);
    final rings = geometry['coordinates'];
    final points = <LatLng>[
      if (geometry['type'] == 'Polygon' &&
          rings is List &&
          rings.isNotEmpty &&
          rings.first is List)
        for (final pair in rings.first as List)
          if (pair is List &&
              pair.length >= 2 &&
              pair[0] is num &&
              pair[1] is num)
            LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
    ];
    final radius = num.tryParse('${order['radiusM']}')?.toDouble();
    final boundary = points.length >= 3 && validCoverage(points)
        ? points
        : radius != null && radius.isFinite && radius > 0
        ? circleBoundary(center, radius)
        : <LatLng>[];
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Monitoring area', 'Vùng giám sát'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => satellite = !satellite),
                icon: const Icon(Icons.layers_outlined),
                label: Text(
                  satellite
                      ? context.tr('Street', 'Đường phố')
                      : context.tr('Satellite', 'Vệ tinh'),
                ),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 216,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  initialCameraFit: boundary.isEmpty
                      ? null
                      : CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(boundary),
                          padding: const EdgeInsets.all(24),
                          maxZoom: 16,
                        ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: satellite
                        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    fallbackUrl: satellite ? null : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'vn.odms.odms_mobile',
                  ),
                  if (boundary.isNotEmpty)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: boundary,
                          color: color.withValues(alpha: .18),
                          borderColor: color,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 26,
                        height: 26,
                        child: Icon(Icons.location_on, color: color),
                      ),
                    ],
                  ),
                  SimpleAttributionWidget(
                    source: Text(
                      satellite
                          ? 'Esri'
                          : '© OpenStreetMap contributors · Esri',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
