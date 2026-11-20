import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/external_link.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

Future<Object?> optionalResource(ApiClient api, String path) async {
  try {
    return await api.request(path);
  } on ApiFailure catch (failure) {
    if (failure.status == 404) return null;
    rethrow;
  }
}

class FinancePage extends ConsumerStatefulWidget {
  const FinancePage({super.key, required this.orderId, this.manager = false});
  final String orderId;
  final bool manager;
  @override
  ConsumerState<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends ConsumerState<FinancePage> {
  String? transaction;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider),
        path = '/api/orders/${segment(widget.orderId)}';
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Quote and payments', 'Báo giá và thanh toán')),
      ),
      body: RemoteView(
        load: () async => {
          'quote': await optionalResource(api, '$path/quote'),
          'invoice': await optionalResource(
            api,
            widget.manager
                ? '/api/manager/orders/${segment(widget.orderId)}/invoice'
                : '$path/invoice',
          ),
          'milestones': await optionalResource(
            api,
            widget.manager
                ? '/api/manager/orders/${segment(widget.orderId)}/mission-payment-milestones'
                : '$path/mission-payment-milestones',
          ),
        },
        builder: (context, data, reload) {
          final quote = object(object(data)['quote']),
              invoice = object(object(data)['invoice']);
          Future<void> pay(String path) async {
            setState(() => busy = true);
            await runAction(context, () async {
              final payment = object(await api.request(path, method: 'POST'));
              transaction = payment['transactionReference'] as String?;
              await openExternal(payment['paymentUrl']);
              return null;
            });
            if (mounted) {
              setState(() => busy = false);
              reload();
            }
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (quote.isEmpty)
                Text(
                  context.tr(
                    'No quote has been issued yet.',
                    'Chưa phát hành báo giá.',
                  ),
                ),
              DetailFields(
                data: quote,
                fields: const {
                  'version': ('Quote version', 'Phiên bản báo giá'),
                  'status': ('Quote status', 'Trạng thái báo giá'),
                  'totalAmount': ('Total (VND)', 'Tổng tiền (VND)'),
                  'expiresAt': ('Expires', 'Hết hạn'),
                  'managerNote': ('Note', 'Ghi chú'),
                },
              ),
              for (final item in records(quote['items']))
                Card(
                  child: ListTile(
                    title: Text('${item['description']}'),
                    subtitle: Text(
                      '${item['quantity']} × ${item['unitPrice']} VND',
                    ),
                    trailing: Text('${item['amount']} VND'),
                  ),
                ),
              if (!widget.manager && quote['status'] == 'APPROVED')
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (await runAction(
                            context,
                            () => api.request(
                              '$path/quotes/${segment('${quote['id']}')}/accept',
                              method: 'POST',
                            ),
                          )) {
                            reload();
                          }
                        },
                  child: Text(context.tr('Accept quote', 'Chấp nhận báo giá')),
                ),
              const Divider(height: 40),
              DetailFields(
                data: invoice,
                fields: const {
                  'invoiceNumber': ('Invoice', 'Hóa đơn'),
                  'status': ('Invoice status', 'Trạng thái hóa đơn'),
                  'totalAmount': ('Total (VND)', 'Tổng tiền (VND)'),
                  'depositAmount': ('Deposit (VND)', 'Tiền cọc (VND)'),
                  'paidAmount': ('Paid (VND)', 'Đã thanh toán (VND)'),
                  'remainingAmount': ('Remaining (VND)', 'Còn lại (VND)'),
                  'depositExpiresAt': (
                    'Deposit deadline',
                    'Hạn thanh toán cọc',
                  ),
                },
              ),
              if (!widget.manager &&
                  invoice.isNotEmpty &&
                  ['ISSUED', 'PARTIALLY_PAID'].contains(invoice['status']) &&
                  invoice['depositStatus'] != 'PAID' &&
                  (invoice['contractRequired'] != true ||
                      invoice['contractConfirmedAt'] != null))
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => pay(
                          '/api/invoices/${segment('${invoice['id']}')}/payments/deposit',
                        ),
                  child: Text(context.tr('Pay deposit', 'Thanh toán cọc')),
                ),
              for (final milestone in records(object(data)['milestones']))
                Card(
                  child: ListTile(
                    title: Text(
                      '${milestone['scopeLabel'] ?? milestone['missionCode']}',
                    ),
                    subtitle: Text(
                      '${milestone['amount']} VND · ${milestone['status']}',
                    ),
                    trailing: !widget.manager && milestone['status'] == 'UNPAID'
                        ? IconButton(
                            onPressed: busy
                                ? null
                                : () => pay(
                                    '/api/mission-payment-milestones/${segment('${milestone['id']}')}/payments',
                                  ),
                            icon: const Icon(Icons.payment),
                          )
                        : null,
                  ),
                ),
              if (transaction != null)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (await runAction(
                            context,
                            () => api.request(
                              '/api/payments/by-reference/${segment(transaction!)}/refresh',
                              method: 'POST',
                            ),
                          )) {
                            reload();
                          }
                        },
                  child: Text(
                    context.tr(
                      'Check payment result',
                      'Kiểm tra kết quả thanh toán',
                    ),
                  ),
                ),
              TextButton(
                onPressed: reload,
                child: Text(context.tr('Refresh', 'Làm mới')),
              ),
            ],
          );
        },
      ),
    );
  }
}
