import '../../shared/portal_scaffold.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/external_link.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class CustomerMediaPage extends ConsumerWidget {
  const CustomerMediaPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider);
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Media library', 'Thư viện dữ liệu')),
      ),
      body: RemoteView(
        load: () => api.request('/api/customer/available-media'),
        builder: (context, data, reload) => RecordList(
          items: records(data),
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
                        await openExternal(view['viewUrl']);
                        return null;
                      }),
                      child: Text(context.tr('Open preview', 'Xem trước')),
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
    );
  }
}
