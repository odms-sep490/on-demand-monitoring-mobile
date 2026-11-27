import '../../shared/portal_scaffold.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../auth/session.dart';

import 'faq_page.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});
  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  int version = 0;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider), user = ref.watch(sessionProvider).user!;
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Support tickets', 'Yêu cầu hỗ trợ')),
        actions: [
          if (user.role == AppRole.customer)
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).push<void>(MaterialPageRoute(builder: (_) => const FaqPage())),
              child: const Text('FAQ'),
            ),
        ],
      ),
      body: RemoteView(
        key: ValueKey(version),
        load: () => api.request('/api/support-tickets'),
        builder: (context, data, reload) => RecordList(
          items: records(data),
          refresh: reload,
          onTap: (item) async {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TicketPage(id: '${item['id']}'),
              ),
            );
            reload();
          },
        ),
      ),
      floatingActionButton: user.role != AppRole.customer
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final body = await editRecord(
                  context,
                  title: context.tr('New support ticket', 'Yêu cầu hỗ trợ mới'),
                  fields: const [
                    FieldSpec('subject', 'Subject', 'Tiêu đề'),
                    FieldSpec(
                      'description',
                      'Description',
                      'Mô tả',
                      kind: FieldKind.multiline,
                    ),
                    FieldSpec(
                      'category',
                      'Category',
                      'Danh mục',
                      kind: FieldKind.choice,
                      options: {
                        'ORDERS': 'Orders / Đơn hàng',
                        'MISSIONS': 'Missions / Nhiệm vụ',
                        'RESULTS': 'Results / Kết quả',
                        'MEDIA': 'Media / Dữ liệu',
                        'SCHEDULING': 'Scheduling / Lịch',
                        'ACCOUNT': 'Account / Tài khoản',
                      },
                    ),
                    FieldSpec(
                      'priority',
                      'Priority',
                      'Độ ưu tiên',
                      kind: FieldKind.choice,
                      initial: 'NORMAL',
                      options: {
                        'NORMAL': 'Normal / Bình thường',
                        'HIGH': 'High / Cao',
                        'URGENT': 'Urgent / Khẩn cấp',
                      },
                    ),
                  ],
                );
                if (body != null &&
                    context.mounted &&
                    await runAction(
                      context,
                      () => api.request(
                        '/api/support-tickets',
                        method: 'POST',
                        body: body,
                      ),
                    ) &&
                    mounted) {
                  setState(() => version++);
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

class TicketPage extends ConsumerWidget {
  const TicketPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        user = ref.watch(sessionProvider).user!,
        path = '/api/support-tickets/${segment(id)}';
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Support conversation', 'Trao đổi hỗ trợ')),
      ),
      body: RemoteView(
        load: () => api.request(path),
        builder: (context, data, reload) {
          final ticket = object(data);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                recordTitle(ticket),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              DetailFields(
                data: ticket,
                fields: const {
                  'ticketCode': ('Ticket', 'Mã hỗ trợ'),
                  'status': ('Status', 'Trạng thái'),
                  'description': ('Description', 'Mô tả'),
                  'assignedStaffName': ('Assigned to', 'Người phụ trách'),
                  'resolutionNotes': ('Resolution', 'Kết quả xử lý'),
                },
              ),
              for (final message in records(ticket['messages']))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${message['senderName']}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Text('${message['content']}'),
                        const SizedBox(height: 8),
                        Text(
                          '${message['createdAt']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              if (!['CLOSED', 'CANCELLED'].contains(ticket['status']))
                FilledButton.icon(
                  icon: const Icon(Icons.reply),
                  onPressed: () async {
                    final body = await editRecord(
                      context,
                      title: context.tr('Reply', 'Trả lời'),
                      fields: const [
                        FieldSpec(
                          'content',
                          'Message',
                          'Nội dung',
                          kind: FieldKind.multiline,
                        ),
                      ],
                    );
                    if (body != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            '$path/messages',
                            method: 'POST',
                            body: body,
                          ),
                        )) {
                      reload();
                    }
                  },
                  label: Text(context.tr('Reply', 'Trả lời')),
                ),
              if (user.role != AppRole.customer)
                OutlinedButton(
                  onPressed: () async {
                    final body = await editRecord(
                      context,
                      title: context.tr('Update ticket', 'Cập nhật yêu cầu'),
                      initial: ticket,
                      fields: const [
                        FieldSpec(
                          'status',
                          'Status',
                          'Trạng thái',
                          kind: FieldKind.choice,
                          options: {
                            'OPEN': 'Open / Mới',
                            'ASSIGNED': 'Assigned / Đã phân công',
                            'IN_PROGRESS': 'In progress / Đang xử lý',
                            'WAITING_FOR_CUSTOMER':
                                'Waiting for customer / Chờ khách hàng',
                            'WAITING_FOR_STAFF':
                                'Waiting for staff / Chờ nhân viên',
                            'RESOLVED': 'Resolved / Đã giải quyết',
                            'CLOSED': 'Closed / Đã đóng',
                          },
                        ),
                        FieldSpec(
                          'resolutionNotes',
                          'Resolution notes',
                          'Ghi chú xử lý',
                          kind: FieldKind.multiline,
                          required: false,
                        ),
                      ],
                    );
                    if (body != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            '$path/status',
                            method: 'PATCH',
                            body: body,
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(
                    context.tr('Update status', 'Cập nhật trạng thái'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
