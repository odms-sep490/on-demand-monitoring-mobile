import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../shared/mobile_ui.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../../shared/workspace_hero.dart';

class StaffMissionWorkspace extends StatelessWidget {
  const StaffMissionWorkspace({
    super.key,
    required this.mission,
    required this.permissions,
    required this.id,
  });
  final Json mission, permissions;
  final String id;

  @override
  Widget build(BuildContext context) {
    final status = recordStatus(mission);
    final colors = Theme.of(context).colorScheme;
    final label =
        mission['scopeLabel'] ?? mission['orderTitle'] ?? recordTitle(mission);
    final schedule = [
      if (mission['scheduledStartAt'] case final String start)
        displayDate(start),
      if (mission['scheduledEndAt'] case final String end) displayDate(end),
    ].join(' → ');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WorkspaceHero(
          title: '$label',
          eyebrow: '${mission['missionCode'] ?? ''}',
          description: schedule,
          action: status.isEmpty
              ? const SizedBox.shrink()
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: StatusPill(status: status),
                ),
        ),
        Text(
          context.tr('Assigned work', 'Công việc được giao'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.checklist_outlined, color: colors.primary),
          title: Text(context.tr('Monitoring checklist', 'Hạng mục giám sát')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/staff/missions/${segment(id)}/checklist'),
        ),
        if (permissions['canUploadMedia'] == true)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.photo_library_outlined, color: colors.primary),
            title: Text(context.tr('Evidence files', 'Tệp minh chứng')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/staff/missions/${segment(id)}/media'),
          ),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          context.tr('Site and assignment', 'Địa điểm và phân công'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        DetailFields(
          data: mission,
          fields: const {
            'orderTitle': ('Order', 'Đơn hàng'),
            'description': ('Description', 'Mô tả'),
            'serviceName': ('Service', 'Dịch vụ'),
            'address': ('Site', 'Địa điểm'),
            'customerName': ('Customer', 'Khách hàng'),
            'flightPermitStatus': ('Permit status', 'Trạng thái giấy phép'),
            'lastRescheduleNote': ('Schedule note', 'Ghi chú lịch'),
          },
        ),
        for (final person in records(mission['staffAssignments']))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text('${person['staffName'] ?? ''}'),
            subtitle: Text(
              '${person['assignedRole'] ?? ''} · ${person['responseStatus'] ?? ''}',
            ),
          ),
        for (final device in records(mission['deviceAssignments']))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.precision_manufacturing_outlined),
            title: Text(
              '${device['deviceName'] ?? device['deviceCode'] ?? ''}',
            ),
            subtitle: Text(
              '${device['deviceRole'] ?? ''} · ${device['status'] ?? ''}',
            ),
          ),
      ],
    );
  }
}
