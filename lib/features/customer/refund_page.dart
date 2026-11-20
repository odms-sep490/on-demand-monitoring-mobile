import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/external_link.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import 'finance_page.dart' show optionalResource;

class RefundPage extends ConsumerWidget {
  const RefundPage({super.key, required this.orderId, required this.manager});
  final String orderId;
  final bool manager;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        root = '/api/${manager ? 'manager/' : ''}orders/${segment(orderId)}';
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Deposit refund', 'Hoàn tiền cọc')),
      ),
      body: RemoteView(
        load: () => optionalResource(api, '$root/deposit-refund'),
        builder: (context, value, reload) {
          final refund = object(value);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (refund.isEmpty)
                Text(
                  context.tr(
                    'No refund request recorded.',
                    'Chưa có yêu cầu hoàn tiền.',
                  ),
                ),
              DetailFields(
                data: refund,
                fields: const {
                  'status': ('Status', 'Trạng thái'),
                  'reason': ('Reason', 'Lý do'),
                  'refundableAmount': ('Refundable (VND)', 'Có thể hoàn (VND)'),
                  'refundedAmount': ('Refunded (VND)', 'Đã hoàn (VND)'),
                  'rejectionReason': ('Review note', 'Ý kiến duyệt'),
                  'requestedAt': ('Requested', 'Yêu cầu lúc'),
                  'completedAt': ('Completed', 'Hoàn tất'),
                },
              ),
              for (final attempt in records(refund['attempts']))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DetailFields(
                          data: attempt,
                          fields: const {
                            'amount': ('Amount (VND)', 'Số tiền (VND)'),
                            'outcome': ('Outcome', 'Kết quả'),
                            'transferredAt': (
                              'Transferred',
                              'Thời gian chuyển',
                            ),
                            'transactionReference': ('Reference', 'Tham chiếu'),
                          },
                        ),
                        for (final receipt in records(attempt['receipts']))
                          TextButton(
                            onPressed: () => runAction(context, () async {
                              final result = object(
                                await api.request(
                                  '/api/deposit-refunds/${segment('${refund['id']}')}/receipts/${segment('${receipt['id']}')}/access',
                                ),
                              );
                              await openExternal(result['url']);
                              return null;
                            }),
                            child: Text('${receipt['fileName']}'),
                          ),
                      ],
                    ),
                  ),
                ),
              if (manager && refund.isEmpty)
                FilledButton(
                  onPressed: () async {
                    final body = await editRecord(
                      context,
                      title: context.tr(
                        'Request deposit refund',
                        'Yêu cầu hoàn tiền cọc',
                      ),
                      fields: const [
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
                            '$root/deposit-refunds',
                            method: 'POST',
                            body: body,
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(
                    context.tr('Request refund', 'Yêu cầu hoàn tiền'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
