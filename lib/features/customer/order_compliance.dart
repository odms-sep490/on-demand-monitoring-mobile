import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/models.dart';
import '../../shared/editor.dart';
import '../../shared/files.dart';
import '../../shared/strings.dart';

Future<Json?> collectOrderCompliance(BuildContext context) async {
  final body = await editRecord(
    context,
    title: context.tr('Permit and authorization', 'Giấy phép và ủy quyền'),
    fields: const [
      FieldSpec(
        'permitStatus',
        'Airspace permit',
        'Giấy phép bay',
        kind: FieldKind.choice,
        options: {
          'NONE': 'No permit / Chưa có giấy phép',
          'HAVE_PERMIT': 'I have a permit / Đã có giấy phép',
          'NEED_SUPPORT': 'Request support / Cần hỗ trợ',
        },
      ),
      FieldSpec(
        'authorizationFile',
        'Attach a monitoring authorization document',
        'Đính kèm tài liệu ủy quyền giám sát',
        kind: FieldKind.toggle,
        required: false,
      ),
      FieldSpec(
        'resultFormats',
        'Result formats',
        'Định dạng kết quả',
        kind: FieldKind.multiChoice,
        initial: ['PHOTO'],
        options: {
          'PHOTO': 'Photos / Ảnh',
          'VIDEO': 'Video',
          'PDF_REPORT': 'PDF report / Báo cáo PDF',
          'ORTHOMOSAIC': 'Orthomosaic / Ảnh trực giao',
          'MODEL_3D': '3D model / Mô hình 3D',
        },
      ),
      FieldSpec(
        'deliveryMethods',
        'Delivery methods',
        'Phương thức nhận kết quả',
        kind: FieldKind.multiChoice,
        initial: ['DOWNLOAD'],
        options: {
          'DOWNLOAD': 'Download / Tải xuống',
          'EMAIL': 'Email',
          'API': 'API',
        },
      ),
    ],
  );
  if (body == null || !context.mounted) return null;
  if (body['permitStatus'] == 'HAVE_PERMIT') {
    final permit = await editRecord(
      context,
      title: context.tr('Permit details', 'Thông tin giấy phép'),
      fields: const [
        FieldSpec('permitNumber', 'Permit number', 'Số giấy phép'),
        FieldSpec(
          'permitExpiresOn',
          'Permit expiry',
          'Ngày hết hạn',
          kind: FieldKind.date,
        ),
      ],
    );
    if (permit == null || !context.mounted) return null;
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (files.isEmpty || !context.mounted) return null;
    if (files.length > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Choose at most 3 permit files.',
              'Chọn tối đa 3 tệp giấy phép.',
            ),
          ),
        ),
      );
      return null;
    }
    body.addAll(permit);
    body['permitDocuments'] = await Future.wait(files.map(inlineDocument));
  }
  if (body.remove('authorizationFile') == true && context.mounted) {
    final doc = await editRecord(
      context,
      title: context.tr('Authorization document', 'Tài liệu ủy quyền'),
      fields: const [
        FieldSpec('documentName', 'Document name', 'Tên tài liệu'),
        FieldSpec(
          'documentType',
          'Document type',
          'Loại tài liệu',
          kind: FieldKind.choice,
          options: {
            'OWNERSHIP_PROOF': 'Ownership proof / Chứng minh sở hữu',
            'OWNER_CONSENT': 'Owner consent / Đồng ý của chủ sở hữu',
            'AUTHORIZATION_LETTER': 'Authorization / Ủy quyền',
            'SERVICE_CONTRACT': 'Service contract / Hợp đồng dịch vụ',
            'ASSIGNMENT_LETTER': 'Assignment / Phân công',
            'OTHER': 'Other / Khác',
          },
        ),
        FieldSpec(
          'notes',
          'Notes',
          'Ghi chú',
          kind: FieldKind.multiline,
          required: false,
        ),
      ],
    );
    if (doc == null || !context.mounted) return null;
    final files = await pickOneFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (files.isEmpty) return null;
    body['monitoringAuthorizationDocuments'] = [
      {...await inlineDocument(files.single), ...doc},
    ];
  }
  return body;
}
