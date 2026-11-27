import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/record_lookup.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class MissionScheduleControl extends ConsumerWidget {
  const MissionScheduleControl({
    super.key,
    required this.mission,
    required this.id,
    required this.reload,
  });

  final Json mission;
  final String id;
  final VoidCallback reload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final path = '/api/missions/${segment(id)}';
    return OutlinedButton(
      onPressed: () async {
        final scope = await editRecord(
          context,
          title: context.tr('Reschedule scope', 'Phạm vi đổi lịch'),
          fields: const [
            FieldSpec(
              'scope',
              'Scope',
              'Phạm vi',
              kind: FieldKind.choice,
              initial: 'MISSION_ONLY',
              options: {
                'MISSION_ONLY': 'Mission only / Chỉ nhiệm vụ',
                'ORDER_AND_MISSION': 'Order and mission / Đơn hàng và nhiệm vụ',
              },
            ),
          ],
        );
        if (scope == null || !context.mounted) return;
        final changeOrder = scope['scope'] == 'ORDER_AND_MISSION';
        final body = await editRecord(
          context,
          title: context.tr('Reschedule', 'Đổi lịch'),
          fields: [
            const FieldSpec(
              'scheduledStartAt',
              'Start (device time zone)',
              'Bắt đầu (múi giờ thiết bị)',
              kind: FieldKind.instant,
            ),
            const FieldSpec(
              'scheduledEndAt',
              'End (device time zone)',
              'Kết thúc (múi giờ thiết bị)',
              kind: FieldKind.instant,
            ),
            const FieldSpec(
              'reason',
              'Reason',
              'Lý do',
              kind: FieldKind.choice,
              options: {
                'WEATHER_UNSAFE': 'Weather / Thời tiết',
                'FLIGHT_PERMISSION_DELAY': 'Permit delay / Chậm giấy phép',
                'RESOURCE_UNAVAILABLE': 'Resources / Nguồn lực',
                'EQUIPMENT_ISSUE': 'Equipment / Thiết bị',
                'SITE_ACCESS_BLOCKED': 'Site access / Tiếp cận địa điểm',
                'CUSTOMER_REQUEST': 'Customer request / Yêu cầu khách hàng',
                'OTHER': 'Other / Khác',
              },
            ),
            const FieldSpec(
              'note',
              'Notes',
              'Ghi chú',
              kind: FieldKind.multiline,
              required: false,
            ),
            const FieldSpec(
              'customerConfirmed',
              'Customer confirmed',
              'Khách hàng đã xác nhận',
              kind: FieldKind.toggle,
              required: false,
            ),
            if (changeOrder) ...[
              FieldSpec(
                'orderPreferredDateFrom',
                'Order start date',
                'Ngày bắt đầu của đơn',
                kind: FieldKind.date,
                initial: mission['orderPreferredDateFrom'],
              ),
              FieldSpec(
                'orderPreferredDateTo',
                'Order end date',
                'Ngày kết thúc của đơn',
                kind: FieldKind.date,
                initial: mission['orderPreferredDateTo'],
              ),
              FieldSpec(
                'orderPreferredTimeId',
                'Order time slot',
                'Khung giờ của đơn',
                kind: FieldKind.choice,
                initial: mission['orderPreferredTimeId'],
                loadOptions: () => lookup(api, '/api/preferred-times'),
              ),
            ],
          ],
          validate: (body) {
            if (body['customerConfirmed'] != true) {
              return context.tr(
                'Confirm with the customer first.',
                'Cần xác nhận với khách hàng trước.',
              );
            }
            if ('${body['scheduledStartAt']}'.compareTo(
                  '${body['scheduledEndAt']}',
                ) >=
                0) {
              return context.tr(
                'End must follow start.',
                'Kết thúc phải sau bắt đầu.',
              );
            }
            if (changeOrder &&
                '${body['orderPreferredDateFrom']}'.compareTo(
                      '${body['orderPreferredDateTo']}',
                    ) >
                    0) {
              return context.tr(
                'Invalid order date range.',
                'Khoảng ngày của đơn không hợp lệ.',
              );
            }
            return null;
          },
        );
        if (body != null &&
            context.mounted &&
            await runAction(
              context,
              () => api.request(
                '$path/schedule',
                method: 'PATCH',
                body: {...body, ...scope},
              ),
            )) {
          reload();
        }
      },
      child: Text(context.tr('Reschedule', 'Đổi lịch')),
    );
  }
}
