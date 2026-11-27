import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

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
