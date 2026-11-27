import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class ChangeAnalysisPage extends ConsumerStatefulWidget {
  const ChangeAnalysisPage({super.key, required this.assets});
  final List<Json> assets;

  @override
  ConsumerState<ChangeAnalysisPage> createState() => _ChangeAnalysisPageState();
}

class _ChangeAnalysisPageState extends ConsumerState<ChangeAnalysisPage> {
  static const path = '/api/customer/ai/change-analyses';
  bool submitting = false;
  String? requestKey;
  Json? pendingPair;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final photos = {
      for (final asset in widget.assets)
        if (asset['mediaType'] == 'IMAGE' &&
            asset['canDownloadOriginal'] == true &&
            asset['mediaId'] is String)
          asset['mediaId'] as String: recordTitle(asset),
    };
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('AI change analysis', 'AI phân tích thay đổi')),
      ),
      body: RemoteView(
        load: () => api.request(path),
        builder: (context, data, reload) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.tr(
                'Compare two delivered photos of the same area.',
                'So sánh hai ảnh đã bàn giao của cùng khu vực.',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.compare_outlined),
              label: Text(context.tr('Choose two photos', 'Chọn hai ảnh')),
              onPressed: submitting || photos.length < 2
                  ? null
                  : () async {
                      final pair = await editRecord(
                        context,
                        title: context.tr('Compare photos', 'So sánh ảnh'),
                        initial: pendingPair ?? {},
                        fields: [
                          FieldSpec(
                            'beforeAsset',
                            'Before',
                            'Ảnh trước',
                            kind: FieldKind.choice,
                            options: photos,
                          ),
                          FieldSpec(
                            'afterAsset',
                            'After',
                            'Ảnh sau',
                            kind: FieldKind.choice,
                            options: photos,
                          ),
                        ],
                        validate: (pair) =>
                            pair['beforeAsset'] == pair['afterAsset']
                            ? context.tr(
                                'Choose two different photos.',
                                'Hãy chọn hai ảnh khác nhau.',
                              )
                            : null,
                      );
                      if (pair == null || !mounted || !context.mounted) return;
                      if (pendingPair?['beforeAsset'] != pair['beforeAsset'] ||
                          pendingPair?['afterAsset'] != pair['afterAsset']) {
                        requestKey = newRequestId();
                      }
                      pendingPair = pair;
                      setState(() => submitting = true);
                      final saved = await runAction(
                        context,
                        () => api.request(
                          path,
                          method: 'POST',
                          body: FormData.fromMap({
                            ...pair,
                            'requestKey': requestKey ??= newRequestId(),
                          }),
                        ),
                      );
                      if (!mounted) return;
                      setState(() => submitting = false);
                      if (saved) {
                        requestKey = null;
                        pendingPair = null;
                        reload();
                      }
                    },
            ),
            if (photos.length < 2)
              Text(
                context.tr(
                  'Two eligible delivered photos are required.',
                  'Cần hai ảnh đã bàn giao đủ điều kiện.',
                ),
              ),
            const Divider(),
            for (final job in records(data))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(_analysisStatus(context, job['status'])),
                subtitle: Text('${job['created_at'] ?? ''}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => _AnalysisResultPage(id: '${job['id']}'),
                    ),
                  );
                  if (context.mounted) reload();
                },
              ),
          ],
        ),
      ),
    );
  }
}

String _analysisStatus(BuildContext context, Object? status) =>
    switch (status) {
      'PENDING' => context.tr('Queued', 'Đang chờ'),
      'PROCESSING' => context.tr('Analyzing', 'Đang phân tích'),
      'COMPLETED' => context.tr('Complete', 'Hoàn tất'),
      'FAILED' => context.tr('Failed', 'Thất bại'),
      _ => '${status ?? ''}',
    };

class _AnalysisResultPage extends ConsumerWidget {
  const _AnalysisResultPage({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    final path = '${_ChangeAnalysisPageState.path}/${segment(id)}';
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Comparison results', 'Kết quả so sánh')),
      ),
      body: RemoteView(
        load: () async {
          final job = object(await api.request(path));
          return {
            'job': job,
            if (job['status'] == 'COMPLETED')
              'result': await api.request('$path/result'),
          };
        },
        builder: (context, data, reload) {
          final job = object(object(data)['job']);
          final result = object(object(data)['result']);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _analysisStatus(context, job['status']),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (job['error_code'] != null) Text('${job['error_code']}'),
              const SizedBox(height: 12),
              for (final (key, label) in [
                ('before', context.tr('Before', 'Ảnh trước')),
                ('after', context.tr('After', 'Ảnh sau')),
                ('overlay', context.tr('Detected changes', 'Vùng thay đổi')),
              ])
                if (_image(result[key]) case final Uint8List bytes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(label),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(
                            bytes,
                            errorBuilder: (_, _, _) => Text(
                              context.tr(
                                'Image could not be displayed.',
                                'Không hiển thị được ảnh.',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              if (result['changedPixelRatio'] case final num changed)
                Text(
                  "${context.tr('Changed area', 'Vùng thay đổi')}: ${(changed * 100).toStringAsFixed(1)}%",
                ),
              OutlinedButton.icon(
                onPressed: reload,
                icon: const Icon(Icons.refresh),
                label: Text(
                  context.tr('Refresh status', 'Cập nhật trạng thái'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Uint8List? _image(Object? data) {
  if (data is! String || data.isEmpty) return null;
  try {
    return base64Decode(data);
  } on FormatException {
    return null;
  }
}
