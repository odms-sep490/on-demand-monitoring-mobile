import '../../shared/portal_scaffold.dart';

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/files.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../auth/session.dart';
import 'media_upload.dart';

class EvidencePage extends ConsumerStatefulWidget {
  const EvidencePage({super.key, required this.missionId});
  final String missionId;
  @override
  ConsumerState<EvidencePage> createState() => _EvidencePageState();
}

class _EvidencePageState extends ConsumerState<EvidencePage> {
  bool uploading = false;
  double progress = 0;
  int version = 0;
  Future<void> upload() async {
    final api = ref.read(apiProvider);
    try {
      final permission = object(
        await api.request(
          '/api/missions/${segment(widget.missionId)}/permissions',
        ),
      );
      if (permission['canUploadMedia'] != true) {
        throw StateError('You cannot upload evidence for this mission.');
      }
      final mission = object(
        await api.request('/api/missions/${segment(widget.missionId)}'),
      );
      if (!mounted) return;
      final details = await editRecord(
        context,
        title: context.tr('Evidence details', 'Thông tin minh chứng'),
        fields: [
          FieldSpec(
            'deviceId',
            'Assigned device',
            'Thiết bị được phân công',
            kind: FieldKind.choice,
            options: {
              for (final item in records(mission['deviceAssignments']))
                '${item['deviceId']}':
                    '${item['deviceName'] ?? item['deviceCode']}',
            },
          ),
          const FieldSpec(
            'capturedAt',
            'Capture time (device time zone)',
            'Thời gian ghi hình (múi giờ thiết bị)',
            kind: FieldKind.instant,
          ),
          const FieldSpec(
            'sourceType',
            'File source',
            'Nguồn tệp',
            kind: FieldKind.choice,
            options: {
              'DRONE_CAMERA': 'Drone camera / Camera drone',
              'SATELLITE_SNAPSHOT': 'Satellite snapshot / Ảnh vệ tinh',
              'MANUAL_UPLOAD': 'Other uploaded file / Tệp tải lên khác',
            },
          ),
          const FieldSpec(
            'confirmed',
            'I confirm the source and capture time of this file',
            'Tôi xác nhận nguồn và thời gian ghi hình của tệp',
            kind: FieldKind.toggle,
          ),
        ],
      );
      if (details == null || !mounted) return;
      final files = await pickOneFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4'],
      );
      if (files.isEmpty || files.single.path == null || !mounted) return;
      final file = files.single,
          ext = files.single.name.split('.').last.toLowerCase();
      setState(() {
        uploading = true;
        progress = 0;
      });
      await MediaUploader(api, ref.read(sessionProvider).user!.id).upload(
        missionId: widget.missionId,
        deviceId: '${details['deviceId']}',
        file: File(file.path!),
        fileName: file.name,
        contentType: ext == 'mp4'
            ? 'video/mp4'
            : ext == 'png'
            ? 'image/png'
            : 'image/jpeg',
        capturedAt: '${details['capturedAt']}',
        sourceType: '${details['sourceType']}',
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
      );
      if (mounted) setState(() => version++);
    } catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$failure')));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !uploading,
    child: PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Mission evidence', 'Minh chứng nhiệm vụ')),
      ),
      body: Column(
        children: [
          if (uploading)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 12),
                  Text('${(progress * 100).round()}%'),
                ],
              ),
            ),
          Expanded(
            child: RemoteView(
              key: ValueKey(version),
              load: () => ref
                  .read(apiProvider)
                  .request(
                    '/api/operator/missions/${segment(widget.missionId)}/media',
                    query: {'page': 0, 'size': 100},
                  ),
              builder: (context, data, reload) =>
                  RecordList(items: records(data), refresh: reload),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: uploading ? null : upload,
        child: const Icon(Icons.upload_file),
      ),
    ),
  );
}
