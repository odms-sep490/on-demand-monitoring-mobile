import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../shared/area_picker.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import 'order_detail.dart';
import 'order_compliance.dart';

export 'orders_page.dart';

Future<Map<String, String>> lookup(
  ApiClient api,
  String path, {
  Json? query,
  String key = 'id',
  String label = 'name',
}) async => {
  for (final item in records(await api.request(path, query: query)))
    '${item[key]}': '${item[label] ?? recordTitle(item)}',
};

Future<bool> createOrder(BuildContext context, ApiClient api) async {
  try {
    return await _createOrder(context, api);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
    return false;
  }
}

Future<bool> _createOrder(BuildContext context, ApiClient api) async {
  final service = await editRecord(
    context,
    title: context.tr('Choose service', 'Chọn dịch vụ'),
    fields: [
      FieldSpec(
        'serviceId',
        'Service',
        'Dịch vụ',
        kind: FieldKind.choice,
        loadOptions: () =>
            lookup(api, '/api/services', query: {'activeOnly': true}),
      ),
    ],
  );
  if (service == null || !context.mounted) return false;
  final details = await editRecord(
    context,
    title: context.tr('Monitoring request', 'Yêu cầu giám sát'),
    fields: [
      const FieldSpec('title', 'Title', 'Tiêu đề'),
      const FieldSpec(
        'description',
        'Description',
        'Mô tả',
        kind: FieldKind.multiline,
        required: false,
      ),
      const FieldSpec('address', 'Site address', 'Địa chỉ giám sát'),
      const FieldSpec(
        'preferredDateFrom',
        'Start date',
        'Từ ngày',
        kind: FieldKind.date,
      ),
      const FieldSpec(
        'preferredDateTo',
        'End date',
        'Đến ngày',
        kind: FieldKind.date,
      ),
      FieldSpec(
        'preferredTimeId',
        'Time slot',
        'Khung giờ',
        kind: FieldKind.choice,
        loadOptions: () => lookup(api, '/api/preferred-times'),
      ),
      const FieldSpec(
        'siteContactName',
        'Site contact',
        'Người liên hệ tại chỗ',
        required: false,
      ),
      const FieldSpec(
        'siteContactPhone',
        'Contact phone',
        'Số điện thoại liên hệ',
        required: false,
      ),
      const FieldSpec(
        'accessNotes',
        'Site access notes',
        'Lưu ý khi tiếp cận',
        kind: FieldKind.multiline,
        required: false,
      ),
      const FieldSpec(
        'altitudeM',
        'Desired altitude (10–120 m)',
        'Độ cao mong muốn (10–120 m)',
        kind: FieldKind.number,
        min: 10,
        max: 120,
        required: false,
      ),
      const FieldSpec(
        'monitoringRelationship',
        'Relationship to site',
        'Quan hệ với địa điểm',
        kind: FieldKind.choice,
        options: {
          'OWNER': 'Owner / Chủ sở hữu',
          'AUTHORIZED_PERSON': 'Authorized person / Người được ủy quyền',
          'CONTRACTOR': 'Contractor / Nhà thầu',
          'MANAGER_OR_SUPERVISOR': 'Manager / Người quản lý',
          'OTHER': 'Other / Khác',
        },
      ),
      const FieldSpec(
        'monitoringAuthorizationConfirmed',
        'I have authority to request monitoring here',
        'Tôi có quyền yêu cầu giám sát tại đây',
        kind: FieldKind.toggle,
      ),
      FieldSpec(
        'deliverableIds',
        'Requested outputs',
        'Sản phẩm yêu cầu',
        kind: FieldKind.multiChoice,
        loadOptions: () => lookup(
          api,
          '/api/service-deliverables',
          query: {'serviceId': service['serviceId']},
          key: 'deliverableTypeId',
          label: 'deliverableTypeName',
        ),
      ),
      const FieldSpec(
        'recurrenceType',
        'Repeat',
        'Lặp lại',
        kind: FieldKind.choice,
        initial: 'NONE',
        options: {
          'NONE': 'Once / Một lần',
          'WEEKLY': 'Weekly / Hàng tuần',
          'MONTHLY': 'Monthly / Hàng tháng',
        },
      ),
      const FieldSpec(
        'recurrenceOccurrences',
        'Number of visits (if repeating)',
        'Số lượt (nếu lặp lại)',
        kind: FieldKind.number,
        min: 2,
        max: 52,
        required: false,
      ),
      const FieldSpec(
        'weatherFallback',
        'If the visit cannot proceed',
        'Nếu không thể thực hiện',
        kind: FieldKind.choice,
        options: {
          'AUTO_RESCHEDULE': 'Reschedule / Đổi lịch',
          'CONTACT_CUSTOMER': 'Contact me / Liên hệ tôi',
          'CANCEL_ORDER': 'Cancel / Hủy đơn',
        },
      ),
      const FieldSpec(
        'resultDeadline',
        'Result deadline',
        'Hạn nhận kết quả',
        kind: FieldKind.date,
        required: false,
      ),
      const FieldSpec(
        'dataRetentionDays',
        'Data retention (days)',
        'Thời hạn lưu trữ (ngày)',
        kind: FieldKind.choice,
        options: {'30': '30', '90': '90', '180': '180', '365': '365'},
      ),
      const FieldSpec(
        'termsAccepted',
        'I accept the terms and data-security commitment',
        'Tôi đồng ý điều khoản và cam kết bảo mật dữ liệu',
        kind: FieldKind.toggle,
      ),
    ],
    validate: (body) {
      if ('${body['preferredDateFrom']}'.compareTo(
            '${body['preferredDateTo']}',
          ) >
          0) {
        return context.tr(
          'End date must follow start date.',
          'Ngày kết thúc phải sau ngày bắt đầu.',
        );
      }
      if (body['resultDeadline'] != null &&
          '${body['resultDeadline']}'.compareTo('${body['preferredDateTo']}') <
              0) {
        return context.tr(
          'Result deadline must follow the monitoring dates.',
          'Hạn kết quả phải sau ngày giám sát.',
        );
      }
      if (body['recurrenceType'] != 'NONE' &&
          body['recurrenceOccurrences'] == null) {
        return context.tr(
          'Enter the number of visits.',
          'Nhập số lượt thực hiện.',
        );
      }
      return null;
    },
  );
  if (details == null || !context.mounted) return false;
  final area = await Navigator.push<Json>(
    context,
    MaterialPageRoute(builder: (_) => const AreaPicker()),
  );
  if (area == null || !context.mounted) return false;
  final compliance = await collectOrderCompliance(context);
  if (compliance == null || !context.mounted) return false;
  final body = {
    ...compliance,
    ...service,
    ...details,
    ...area,
    'dataRetentionDays': int.parse('${details['dataRetentionDays']}'),
    'deliverables': (details['deliverableIds'] as List)
        .map(
          (id) => {'deliverableTypeId': id, 'requirement': <String, dynamic>{}},
        )
        .toList(),
  }..remove('deliverableIds');
  if (body['recurrenceType'] == 'NONE') body.remove('recurrenceOccurrences');
  return runAction(
    context,
    () => api.request('/api/orders', method: 'POST', body: body),
  );
}

class CustomerOrderPage extends ConsumerWidget {
  const CustomerOrderPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      OrderDetailPage(id: id, manager: false);
}
