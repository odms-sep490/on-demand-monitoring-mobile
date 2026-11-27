import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/record_lookup.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import 'order_compliance.dart';

Future<Json?> collectSiteDetails(BuildContext context) => editRecord(
  context,
  title: context.tr(
    '4. Site details and authority',
    '4. Chi tiết & quyền giám sát',
  ),
  fields: [
    const FieldSpec(
      'estimatedLengthM',
      'Linear site length (m)',
      'Chiều dài mục tiêu tuyến (m)',
      kind: FieldKind.number,
      min: 0.001,
      max: 100000,
      required: false,
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
  ],
);

Future<Json?> collectOrderSchedule(BuildContext context, ApiClient api) {
  final businessNow = DateTime.now().toUtc().add(const Duration(hours: 7));
  final earliestDate = DateTime(
    businessNow.year,
    businessNow.month,
    businessNow.day + 7,
  );
  return editRecord(
    context,
    title: context.tr('5. Schedule', '5. Thời gian'),
    fields: [
      FieldSpec(
        'preferredDateFrom',
        'Start date',
        'Từ ngày',
        kind: FieldKind.date,
        firstDate: earliestDate,
      ),
      FieldSpec(
        'preferredDateTo',
        'End date',
        'Đến ngày',
        kind: FieldKind.date,
        firstDate: earliestDate,
      ),
      FieldSpec(
        'preferredTimeId',
        'Time slot',
        'Khung giờ',
        kind: FieldKind.choice,
        loadOptions: () => lookup(api, '/api/preferred-times'),
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
    ],
    validate: (body) {
      final start = DateTime.tryParse('${body['preferredDateFrom']}');
      if (start == null || start.isBefore(earliestDate)) {
        return context.tr(
          'Book monitoring at least 7 days in advance.',
          'Vui lòng đặt lịch giám sát trước ít nhất 7 ngày.',
        );
      }
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
}

Future<Json?> collectDeliveryPreferences(
  BuildContext context,
  ApiClient api,
  String serviceId,
) => editRecord(
  context,
  title: context.tr(
    '6. Deliverables and confirmation',
    '6. Kết quả bàn giao & xác nhận',
  ),
  fields: [
    ...orderDeliveryFields,
    FieldSpec(
      'deliverableIds',
      'Requested outputs',
      'Sản phẩm yêu cầu',
      kind: FieldKind.multiChoice,
      loadOptions: () => lookup(
        api,
        '/api/service-deliverables',
        query: {'serviceId': serviceId},
        key: 'deliverableTypeId',
        label: 'deliverableTypeName',
      ),
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
);
