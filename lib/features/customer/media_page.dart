import '../../shared/portal_scaffold.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/external_link.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class CustomerMediaPage extends ConsumerStatefulWidget {
  const CustomerMediaPage({super.key});
  @override
  ConsumerState<CustomerMediaPage> createState() => _CustomerMediaPageState();
}

class _CustomerMediaPageState extends ConsumerState<CustomerMediaPage> {
  String search = '';
  String? type;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Media library', 'Thư viện dữ liệu')),
      ),
      body: RemoteView(
        load: () => api.request('/api/customer/available-media'),
        builder: (context, data, reload) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: context.tr(
                        'Search by filename or mission',
                        'Tìm theo tên tệp hoặc nhiệm vụ',
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => search = value.trim().toLowerCase()),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in <String?, String>{
                        null: context.tr('All', 'Tất cả'),
                        'IMAGE': context.tr('Photos', 'Ảnh'),
                        'VIDEO': 'Video',
                      }.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: type == entry.key,
                          onSelected: (_) => setState(() => type = entry.key),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RecordList(
                items: records(data)
                    .where(
                      (item) =>
                          (type == null || item['mediaType'] == type) &&
                          "${item['fileName'] ?? ''} ${item['missionCode'] ?? ''}"
                              .toLowerCase()
                              .contains(search),
                    )
                    .toList(),
                refresh: reload,
                onTap: (item) => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PortalScaffold(
                      appBar: AppBar(title: Text('${item['fileName'] ?? ''}')),
                      body: ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          if (item['thumbnailUrl'] is String)
                            Image.network(
                              item['thumbnailUrl'] as String,
                              height: 240,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.image_not_supported_outlined,
                                size: 80,
                              ),
                            ),
                          DetailFields(
                            data: item,
                            fields: const {
                              'mediaType': ('Type', 'Loại'),
                              'fileName': ('File', 'Tệp'),
                              'capturedAt': ('Captured', 'Thời gian ghi hình'),
                              'fileSize': ('Size (bytes)', 'Dung lượng (byte)'),
                            },
                          ),
                          FilledButton(
                            onPressed: () => runAction(context, () async {
                              final view = object(
                                await api.request(
                                  '/api/customer/media/${segment('${item['mediaId']}')}/view-url',
                                  method: 'POST',
                                ),
                              );
                              final url = view['viewUrl'];
                              if (item['mediaType'] != 'IMAGE' ||
                                  url is! String) {
                                await openExternal(url);
                              } else if (context.mounted) {
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(
                                        title: Text('${item['fileName']}'),
                                      ),
                                      body: Center(
                                        child: InteractiveViewer(
                                          child: Image.network(
                                            url,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) => Text(
                                              context.tr(
                                                'Unable to load image',
                                                'Không tải được ảnh',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return null;
                            }),
                            child: Text(
                              context.tr('Open preview', 'Xem trước'),
                            ),
                          ),
                          if (item['canDownloadOriginal'] == true)
                            OutlinedButton.icon(
                              icon: const Icon(Icons.download),
                              onPressed: () => runAction(context, () async {
                                final download = object(
                                  await api.request(
                                    '/api/customer/media/${segment('${item['mediaId']}')}/download-url',
                                    method: 'POST',
                                  ),
                                );
                                await openExternal(download['downloadUrl']);
                                return null;
                              }),
                              label: Text(
                                context.tr('Download original', 'Tải bản gốc'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
