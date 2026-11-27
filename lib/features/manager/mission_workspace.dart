import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import 'delivery_page.dart';
import 'manager_pages.dart';
import 'mission_actions.dart';
import 'mission_assignments.dart';
import 'mission_finance_page.dart';
import 'mission_planning_controls.dart';
import 'mission_resource_options.dart';
import 'mission_schedule_control.dart';
import 'review_page.dart';

class ManagerMissionWorkspace extends StatelessWidget {
  const ManagerMissionWorkspace({
    super.key,
    required this.mission,
    required this.permissions,
    required this.id,
    required this.reload,
  });

  final Json mission, permissions;
  final String id;
  final VoidCallback reload;

  @override
  Widget build(BuildContext context) {
    final planning = mission['status'] == 'PLANNING';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '${mission['missionCode'] ?? ''}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        DetailFields(
          data: mission,
          fields: const {
            'status': ('Status', 'Trạng thái'),
            'orderTitle': ('Order', 'Đơn hàng'),
            'description': ('Description', 'Mô tả'),
            'serviceName': ('Service', 'Dịch vụ'),
            'address': ('Site', 'Địa điểm'),
            'scheduledStartAt': ('Start', 'Bắt đầu'),
            'scheduledEndAt': ('End', 'Kết thúc'),
            'customerName': ('Customer', 'Khách hàng'),
            'flightPermitStatus': ('Permit status', 'Trạng thái giấy phép'),
            'lastRescheduleNote': ('Schedule note', 'Ghi chú lịch'),
          },
        ),

        MissionAssignments(mission: mission, id: id, reload: reload),
        if (planning)
          MissionResourceOptions(id: id, mission: mission, reload: reload),
        OutlinedButton.icon(
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(context.tr('Mission finances', 'Tài chính nhiệm vụ')),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => MissionFinancePage(missionId: id),
            ),
          ),
        ),
        if (mission['orderId'] is String && mission['status'] == 'COMPLETED')
          OutlinedButton.icon(
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(context.tr('Mission delivery', 'Bàn giao nhiệm vụ')),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ManagerDeliveryPage(
                  orderId: mission['orderId'] as String,
                  missionId: id,
                ),
              ),
            ),
          ),
        ManagerMissionActions(
          mission: mission,
          permissions: permissions,
          reload: reload,
        ),
        OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => MissionReviewPage(missionId: id),
            ),
          ),
          child: Text(
            context.tr(
              'Review evidence and report',
              'Duyệt minh chứng và báo cáo',
            ),
          ),
        ),

        OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ExecutionPlanPage(
                orderId: '${mission['orderId']}',
                reworkCaseId: mission['resultRevisionCaseId'] as String?,
              ),
            ),
          ),
          child: Text(
            context.tr('Order execution plan', 'Kế hoạch thực hiện đơn hàng'),
          ),
        ),

        if (planning)
          MissionPlanningControls(mission: mission, id: id, reload: reload),
        if (!['COMPLETED', 'CANCELLED', 'FAILED'].contains(mission['status']))
          MissionScheduleControl(mission: mission, id: id, reload: reload),
      ],
    );
  }
}
