import '../../shared/portal_scaffold.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import 'finance_page.dart' show optionalResource;
import 'refund_page.dart';

class CancellationPage extends ConsumerWidget {
  const CancellationPage({
    super.key,
    required this.orderId,
    required this.manager,
  });
  final String orderId;
  final bool manager;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        path = '/api/orders/${segment(orderId)}/contract';
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Contract cancellation', 'Hủy hợp đồng')),
      ),
      body: RemoteView(
        load: () async => {
          'contract': await api.request(path),
          'cancellation': await optionalResource(api, '$path/cancellation'),
        },
        builder: (context, value, reload) {
          final contract = object(object(value)['contract']),
              cancellation = object(object(value)['cancellation']);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DetailFields(
                data: cancellation,
                fields: const {
                  'status': ('Cancellation status', 'Trạng thái hủy'),
                  'responsibility': ('Responsibility', 'Trách nhiệm'),
                  'reason': ('Reason', 'Lý do'),
                  'basis': ('Basis', 'Căn cứ'),
                  'depositPaid': (
                    'Deposit paid (VND)',
                    'Cọc đã thanh toán (VND)',
                  ),
                },
              ),
              if (manager &&
                  contract['status'] != 'CONFIRMED' &&
                  (cancellation.isEmpty && contract['status'] != 'CANCELLED' ||
                      cancellation['status'] == 'REVIEW_REQUIRED'))
                FilledButton(
                  onPressed: () async {
                    final body = await editRecord(
                      context,
                      title: context.tr(
                        'Cancellation decision',
                        'Quyết định hủy',
                      ),
                      fields: [
                        if (cancellation.isEmpty)
                          const FieldSpec(
                            'reason',
                            'Cancellation reason',
                            'Lý do hủy',
                            kind: FieldKind.multiline,
                          ),
                        FieldSpec(
                          'responsibility',
                          'Responsibility',
                          'Trách nhiệm',
                          kind: FieldKind.choice,
                          options: {
                            if (cancellation.isEmpty)
                              'UNRESOLVED': 'Needs review / Cần xem xét',
                            'SYSTEM': 'System / Hệ thống',
                            'CUSTOMER': 'Customer / Khách hàng',
                          },
                        ),
                        const FieldSpec(
                          'basis',
                          'Decision basis',
                          'Căn cứ quyết định',
                          kind: FieldKind.multiline,
                        ),
                        const FieldSpec(
                          'customerLiabilityAcknowledged',
                          'Customer liability has been acknowledged',
                          'Đã xác nhận trách nhiệm khách hàng',
                          kind: FieldKind.toggle,
                          required: false,
                        ),
                      ],
                      validate: (data) {
                        if (cancellation.isEmpty &&
                                '${data['reason']}'.trim().length < 10 ||
                            '${data['basis']}'.trim().length < 10) {
                          return context.tr(
                            'Provide at least 10 characters for the reason and basis.',
                            'Nhập lý do và căn cứ ít nhất 10 ký tự.',
                          );
                        }
                        if (data['responsibility'] == 'CUSTOMER' &&
                            data['customerLiabilityAcknowledged'] != true) {
                          return context.tr(
                            'Customer liability must be acknowledged.',
                            'Cần xác nhận trách nhiệm khách hàng.',
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
                            cancellation.isEmpty
                                ? '$path/cancellation'
                                : '$path/cancellation/decision',
                            method: 'POST',
                            body: {
                              ...body,
                              'customerLiabilityAcknowledged':
                                  body['customerLiabilityAcknowledged'] ??
                                  false,
                              'expectedVersion': cancellation.isEmpty
                                  ? contract['version']
                                  : cancellation['version'],
                              if (cancellation.isEmpty)
                                'clientRequestId':
                                    'mobile-${DateTime.now().microsecondsSinceEpoch}',
                            },
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(
                    context.tr(
                      'Record cancellation decision',
                      'Ghi nhận quyết định hủy',
                    ),
                  ),
                ),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RefundPage(orderId: orderId, manager: manager),
                  ),
                ),
                child: Text(
                  context.tr('Refund status', 'Tình trạng hoàn tiền'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
