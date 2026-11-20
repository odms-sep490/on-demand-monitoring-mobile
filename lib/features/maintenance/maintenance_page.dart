import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../auth/session.dart';
import '../customer/customer_pages.dart' show lookup;

class MaintenancePage extends ConsumerWidget {
  const MaintenancePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider), user = ref.watch(sessionProvider).user!;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Maintenance', 'Bảo trì'))),
      body: RemoteView(
        load: () => api.request(
          '/api/maintenance-tickets',
          query: {if (user.role == AppRole.staff) 'staffId': user.id},
        ),
        builder: (context, data, reload) => RecordList(
          items: records(data),
          refresh: reload,
          onTap: (item) async {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => MaintenanceDetailPage(id: '${item['id']}'),
              ),
            );
            reload();
          },
        ),
      ),
    );
  }
}

class MaintenanceDetailPage extends ConsumerWidget {
  const MaintenanceDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        user = ref.watch(sessionProvider).user!,
        path = '/api/maintenance-tickets/${segment(id)}';
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Maintenance details', 'Chi tiết bảo trì')),
      ),
      body: RemoteView(
        load: () => api.request(path),
        builder: (context, data, reload) {
          final item = object(data),
              open = !['RESOLVED', 'CLOSED'].contains(object(data)['status']);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DetailFields(
                data: item,
                fields: const {
                  'ticketCode': ('Ticket', 'Mã yêu cầu'),
                  'deviceCode': ('Device', 'Thiết bị'),
                  'issueType': ('Issue', 'Sự cố'),
                  'severity': ('Severity', 'Mức độ'),
                  'description': ('Description', 'Mô tả'),
                  'status': ('Status', 'Trạng thái'),
                  'assignedTechnicianName': (
                    'Assigned staff',
                    'Nhân viên phụ trách',
                  ),
                  'resolutionNotes': ('Resolution', 'Kết quả xử lý'),
                },
              ),
              if (user.role == AppRole.manager && open)
                FilledButton(
                  onPressed: () async {
                    final body = await editRecord(
                      context,
                      title: context.tr('Assign staff', 'Phân công nhân viên'),
                      fields: [
                        FieldSpec(
                          'staffId',
                          'Staff',
                          'Nhân viên',
                          kind: FieldKind.choice,
                          loadOptions: () => lookup(
                            api,
                            '/api/operators/available',
                            label: 'fullName',
                          ),
                        ),
                      ],
                    );
                    if (body != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            '$path/assign-staff',
                            method: 'PATCH',
                            body: body,
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(
                    context.tr('Assign staff', 'Phân công nhân viên'),
                  ),
                ),
              if (open &&
                  user.role == AppRole.staff &&
                  item['assignedTechnicianId'] == user.id)
                FilledButton(
                  onPressed: () async {
                    final body = await editRecord(
                      context,
                      title: context.tr(
                        'Resolve maintenance',
                        'Hoàn tất bảo trì',
                      ),
                      fields: const [
                        FieldSpec(
                          'resolutionNotes',
                          'Repair notes',
                          'Ghi chú sửa chữa',
                          kind: FieldKind.multiline,
                        ),
                        FieldSpec(
                          'newDeviceStatus',
                          'Device status',
                          'Trạng thái thiết bị',
                          kind: FieldKind.choice,
                          options: {
                            'AVAILABLE': 'Available / Sẵn sàng',
                            'OUT_OF_SERVICE':
                                'Out of service / Ngừng hoạt động',
                            'MAINTENANCE': 'Maintenance / Bảo trì',
                          },
                        ),
                      ],
                    );
                    if (body != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            '$path/resolve',
                            method: 'PATCH',
                            body: body,
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(context.tr('Resolve', 'Hoàn tất')),
                ),
            ],
          );
        },
      ),
    );
  }
}
