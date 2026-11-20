import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/files.dart';
import '../../shared/external_link.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../auth/session.dart';

class LicensesPage extends ConsumerStatefulWidget {
  const LicensesPage({super.key});
  @override
  ConsumerState<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends ConsumerState<LicensesPage> {
  int version = 0;
  Future<void> edit({Json initial = const {}}) async {
    final body = await editRecord(
      context,
      title: context.tr('Qualification', 'Chứng chỉ'),
      initial: initial,
      fields: const [
        FieldSpec(
          'licenseType',
          'Type',
          'Loại',
          kind: FieldKind.choice,
          options: {
            'PILOT': 'Pilot / Phi công',
            'TECHNICAL': 'Technical / Kỹ thuật',
            'OTHER': 'Other / Khác',
          },
        ),
        FieldSpec('licenseNumber', 'License number', 'Số chứng chỉ'),
        FieldSpec('licenseName', 'License name', 'Tên chứng chỉ'),
        FieldSpec('issuingAuthority', 'Issuing authority', 'Cơ quan cấp'),
        FieldSpec(
          'issuedDate',
          'Issued date',
          'Ngày cấp',
          kind: FieldKind.date,
        ),
        FieldSpec(
          'expiryDate',
          'Expiry date',
          'Ngày hết hạn',
          kind: FieldKind.date,
          required: false,
        ),
        FieldSpec(
          'licenseStatus',
          'Status',
          'Trạng thái',
          kind: FieldKind.choice,
          initial: 'ACTIVE',
          options: {
            'ACTIVE': 'Active / Hiệu lực',
            'EXPIRED': 'Expired / Hết hạn',
            'SUSPENDED': 'Suspended / Tạm đình chỉ',
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
    if (body == null || !mounted) return;
    final api = ref.read(apiProvider), user = ref.read(sessionProvider).user!;
    if (await runAction(
          context,
          () => api.request(
            initial.isEmpty
                ? '/api/staff-licenses'
                : '/api/staff-licenses/${segment('${initial['id']}')}',
            method: initial.isEmpty ? 'POST' : 'PUT',
            body: {'userId': user.id, ...body},
          ),
        ) &&
        mounted) {
      setState(() => version++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider), user = ref.watch(sessionProvider).user!;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('My qualifications', 'Chứng chỉ của tôi')),
      ),
      body: RemoteView(
        key: ValueKey(version),
        load: () =>
            api.request('/api/staff-licenses/users/${segment(user.id)}'),
        builder: (context, data, reload) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final item in records(data))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DetailFields(
                        data: item,
                        fields: const {
                          'licenseName': ('Qualification', 'Chứng chỉ'),
                          'licenseNumber': ('License number', 'Số chứng chỉ'),
                          'issuingAuthority': (
                            'Issuing authority',
                            'Cơ quan cấp',
                          ),
                          'expiryDate': ('Expires', 'Hết hạn'),
                          'licenseStatus': ('Status', 'Trạng thái'),
                          'verificationStatus': ('Verification', 'Xác minh'),
                        },
                      ),
                      if (item['licenseStatus'] != 'REVOKED')
                        OutlinedButton(
                          onPressed: () => edit(initial: item),
                          child: Text(context.tr('Edit', 'Chỉnh sửa')),
                        ),
                      if (item['documentFileName'] != null)
                        TextButton(
                          onPressed: () => runAction(context, () async {
                            await openExternal(
                              object(
                                await api.request(
                                  '/api/staff-licenses/${segment('${item['id']}')}/document',
                                ),
                              )['url'],
                            );
                            return null;
                          }),
                          child: Text(
                            context.tr('View document', 'Xem tài liệu'),
                          ),
                        ),
                      OutlinedButton(
                        onPressed: () async {
                          final files = await pickOneFile(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                          );
                          if (files.isEmpty ||
                              files.single.path == null ||
                              !context.mounted) {
                            return;
                          }
                          final body = FormData.fromMap({
                            'file': await MultipartFile.fromFile(
                              files.single.path!,
                              filename: files.single.name,
                            ),
                          });
                          if (context.mounted &&
                              await runAction(
                                context,
                                () => api.request(
                                  '/api/staff-licenses/${segment('${item['id']}')}/document',
                                  method: 'POST',
                                  body: body,
                                ),
                              )) {
                            reload();
                          }
                        },
                        child: Text(
                          context.tr('Upload document', 'Tải lên tài liệu'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (records(data).isEmpty)
              Text(
                context.tr('No qualifications added.', 'Chưa có chứng chỉ.'),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: edit,
        child: const Icon(Icons.add),
      ),
    );
  }
}
