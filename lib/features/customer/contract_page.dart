import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/external_link.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class ContractPage extends ConsumerWidget {
  const ContractPage({super.key, required this.orderId, required this.manager});
  final String orderId;
  final bool manager;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        path = '/api/orders/${segment(orderId)}/contract';
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Contract', 'Hợp đồng'))),
      body: RemoteView(
        load: () => api.request(path),
        builder: (context, value, reload) {
          final contract = object(value);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DetailFields(
                data: contract,
                fields: const {
                  'contractNumber': ('Contract number', 'Số hợp đồng'),
                  'status': ('Status', 'Trạng thái'),
                  'version': ('Version', 'Phiên bản'),
                  'issuedAt': ('Issued', 'Phát hành'),
                  'confirmedAt': ('Confirmed', 'Xác nhận'),
                },
              ),
              if (contract['document'] != null)
                OutlinedButton.icon(
                  onPressed: () => runAction(context, () async {
                    await openExternal(
                      object(
                        await api.request('$path/download', method: 'POST'),
                      )['url'],
                    );
                    return null;
                  }),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(context.tr('Download contract', 'Tải hợp đồng')),
                ),
              if (!manager &&
                  [
                    'AWAITING_SIGNATURE',
                    'CHANGES_REQUESTED',
                  ].contains(contract['status']))
                FilledButton.icon(
                  onPressed: () async {
                    final files = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );
                    if (files.isEmpty || !context.mounted) return;
                    final file = files.single;
                    if (file.path == null) return;
                    final body = FormData.fromMap({
                      'expectedVersion': '${contract['version']}',
                      'file': await MultipartFile.fromFile(
                        file.path!,
                        filename: file.name,
                        contentType: DioMediaType('application', 'pdf'),
                      ),
                    });
                    if (context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            '$path/submissions',
                            method: 'POST',
                            body: body,
                          ),
                        )) {
                      reload();
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    context.tr('Upload signed PDF', 'Tải lên PDF đã ký'),
                  ),
                ),
              if (manager &&
                  [
                    'NOT_ISSUED',
                    'CHANGES_REQUESTED',
                  ].contains(contract['status']))
                FilledButton(
                  onPressed: () async {
                    final fields = await editRecord(
                      context,
                      title: context.tr('Issue contract', 'Phát hành hợp đồng'),
                      fields: const [
                        FieldSpec(
                          'contractNumber',
                          'Contract number',
                          'Số hợp đồng',
                          required: false,
                        ),
                      ],
                    );
                    if (fields == null) return;
                    final files = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );
                    if (files.isEmpty ||
                        files.single.path == null ||
                        !context.mounted) {
                      return;
                    }
                    final body = FormData.fromMap({
                      ...fields,
                      'quoteId': contract['quoteId'],
                      'file': await MultipartFile.fromFile(
                        files.single.path!,
                        filename: files.single.name,
                        contentType: DioMediaType('application', 'pdf'),
                      ),
                    });
                    if (context.mounted &&
                        await runAction(
                          context,
                          () => api.request(
                            '$path/issue',
                            method: 'POST',
                            body: body,
                          ),
                        )) {
                      reload();
                    }
                  },
                  child: Text(
                    context.tr('Issue contract PDF', 'Phát hành PDF hợp đồng'),
                  ),
                ),
              for (final submission in records(contract['submissions']))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DetailFields(
                          data: submission,
                          fields: const {
                            'submissionNumber': ('Submission', 'Lần nộp'),
                            'status': ('Status', 'Trạng thái'),
                            'submittedAt': ('Submitted', 'Đã nộp'),
                            'reviewNote': ('Review note', 'Ý kiến duyệt'),
                          },
                        ),
                        OutlinedButton(
                          onPressed: () => runAction(context, () async {
                            await openExternal(
                              object(
                                await api.request(
                                  '$path/download',
                                  method: 'POST',
                                  query: {'submissionId': submission['id']},
                                ),
                              )['url'],
                            );
                            return null;
                          }),
                          child: Text(
                            context.tr(
                              'Download signed document',
                              'Tải tài liệu đã ký',
                            ),
                          ),
                        ),
                        if (manager && submission['status'] == 'PENDING') ...[
                          FilledButton(
                            onPressed: () async {
                              if (await runAction(
                                context,
                                () => api.request(
                                  '$path/confirm',
                                  method: 'POST',
                                  body: {
                                    'expectedVersion': contract['version'],
                                    'submissionId': submission['id'],
                                  },
                                ),
                              )) {
                                reload();
                              }
                            },
                            child: Text(
                              context.tr(
                                'Confirm signature',
                                'Xác nhận chữ ký',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final body = await editRecord(
                                context,
                                title: context.tr(
                                  'Request changes',
                                  'Yêu cầu sửa đổi',
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
                                      '$path/request-changes',
                                      method: 'POST',
                                      body: {
                                        ...body,
                                        'expectedVersion': contract['version'],
                                        'submissionId': submission['id'],
                                      },
                                    ),
                                  )) {
                                reload();
                              }
                            },
                            child: Text(
                              context.tr('Request changes', 'Yêu cầu sửa đổi'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
