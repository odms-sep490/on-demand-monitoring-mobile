import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class MissionFinancePage extends ConsumerWidget {
  const MissionFinancePage({super.key, required this.missionId});
  final String missionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Mission finances', 'Tài chính nhiệm vụ')),
      ),
      body: RemoteView(
        load: () => api.request(
          '/api/manager/missions/${segment(missionId)}/financial-summary',
        ),
        builder: (context, data, reload) {
          final summary = object(data);
          final invoice = object(summary['invoice']);
          final payment = object(summary['missionPayment']);
          final breakdown = object(summary['priceBreakdown']);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (summary['purpose'] == 'REWORK')
                Text(
                  context.tr(
                    'This is a rework mission.',
                    'Đây là nhiệm vụ bổ sung.',
                  ),
                )
              else ...[
                DetailFields(
                  data: {
                    ...breakdown,
                    'checklistAmount':
                        breakdown['checklistAmount'] ??
                        summary['missionGrossChecklistAmount'],
                  },
                  fields: const {
                    'checklistAmount': (
                      'Checklist amount (VND)',
                      'Giá hạng mục (VND)',
                    ),
                    'allocatedAdjustment': (
                      'Allocated adjustment (VND)',
                      'Điều chỉnh phân bổ (VND)',
                    ),
                    'missionTotalAmount': (
                      'Mission total (VND)',
                      'Tổng tiền nhiệm vụ (VND)',
                    ),
                    'allocatedDeposit': (
                      'Allocated deposit (VND)',
                      'Cọc phân bổ (VND)',
                    ),
                    'milestoneAmount': (
                      'Milestone amount (VND)',
                      'Thanh toán đợt (VND)',
                    ),
                  },
                ),
                if (invoice.isNotEmpty)
                  Card(
                    child: ExpansionTile(
                      title: Text(
                        context.tr('Order invoice', 'Hóa đơn đơn hàng'),
                      ),
                      children: [
                        DetailFields(
                          data: invoice,
                          fields: const {
                            'totalAmount': ('Total (VND)', 'Tổng cộng (VND)'),
                            'depositAmount': (
                              'Deposit (VND)',
                              'Tiền cọc (VND)',
                            ),
                            'paidAmount': ('Paid (VND)', 'Đã trả (VND)'),
                            'remainingAmount': (
                              'Remaining (VND)',
                              'Còn lại (VND)',
                            ),
                            'depositStatus': (
                              'Deposit status',
                              'Trạng thái cọc',
                            ),
                            'depositExpiresAt': (
                              'Deposit deadline',
                              'Hạn đóng cọc',
                            ),
                          },
                        ),
                      ],
                    ),
                  ),
                if (payment.isNotEmpty)
                  Card(
                    child: ExpansionTile(
                      title: Text(
                        context.tr('Mission payment', 'Thanh toán nhiệm vụ'),
                      ),
                      children: [
                        DetailFields(
                          data: payment,
                          fields: const {
                            'amount': ('Amount (VND)', 'Số tiền (VND)'),
                            'status': ('Status', 'Trạng thái'),
                            'handedOverAt': ('Handed over', 'Đã bàn giao'),
                            'paymentExpiresAt': (
                              'Payment deadline',
                              'Hạn thanh toán',
                            ),
                          },
                        ),
                      ],
                    ),
                  ),
                for (final entry in [
                  ...records(summary['depositPayments']),
                  ...records(payment['payments']),
                ])
                  Card(
                    child: ListTile(
                      title: Text(
                        "${entry['amount']} VND · ${entry['status']}",
                      ),
                      subtitle: DetailFields(
                        data: entry,
                        fields: const {
                          'type': ('Type', 'Loại'),
                          'provider': ('Provider', 'Nhà cung cấp'),
                          'transactionReferenceMasked': (
                            'Reference',
                            'Mã giao dịch',
                          ),
                          'paidAt': ('Paid at', 'Thời điểm thanh toán'),
                        },
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
