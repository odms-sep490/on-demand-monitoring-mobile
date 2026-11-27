import '../../shared/mobile_ui.dart';
import '../../shared/workspace_hero.dart';
import '../../shared/portal_scaffold.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import '../auth/session.dart';
import '../customer/customer_pages.dart' show lookup;

Future<List<Json>> allPages(ApiClient api, String path) async {
  final result = <Json>[];
  for (var page = 0; page < 1000; page++) {
    final data = await api.request(path, query: {'page': page, 'size': 100});
    result.addAll(records(data));
    final pagination = object(data);
    if (data is List ||
        pagination['last'] == true ||
        (pagination['totalPages'] is num &&
            page + 1 >= (pagination['totalPages'] as num)) ||
        records(data).isEmpty) {
      return result;
    }
  }
  throw const ApiFailure('Too many pages. Please narrow the request.');
}

class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        manager = ref.watch(sessionProvider).user!.role == AppRole.manager;
    return PortalScaffold(
      appBar: AppBar(title: Text(context.tr('Devices', 'Thiết bị'))),
      body: RemoteView(
        load: () => allPages(api, '/api/drones'),
        builder: (context, data, reload) => RecordList(
          items: records(data),
          refresh: reload,
          onTap: (item) async {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => DevicePage(id: '${item['id']}'),
              ),
            );
            reload();
          },
        ),
      ),
      floatingActionButton: manager
          ? FloatingActionButton(
              onPressed: () async {
                final body = await editDevice(context, api);
                if (body != null &&
                    context.mounted &&
                    await runAction(
                      context,
                      () => api.request(
                        '/api/drones',
                        method: 'POST',
                        body: body,
                      ),
                    ) &&
                    context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

Future<Json?> editDevice(
  BuildContext context,
  ApiClient api, {
  Json initial = const {},
}) => editRecord(
  context,
  title: context.tr('Device details', 'Thông tin thiết bị'),
  initial: initial,
  fields: [
    const FieldSpec('name', 'Name', 'Tên'),
    const FieldSpec('serialNumber', 'Serial number', 'Số sê-ri'),
    FieldSpec(
      'modelId',
      'Model',
      'Mẫu thiết bị',
      kind: FieldKind.choice,
      loadOptions: () =>
          lookup(api, '/api/device-models', query: {'page': 0, 'size': 100}),
    ),
  ],
);

class DevicePage extends ConsumerWidget {
  const DevicePage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiProvider),
        manager = ref.watch(sessionProvider).user!.role == AppRole.manager,
        path = '/api/drones/${segment(id)}';
    return PortalScaffold(
      appBar: AppBar(
        title: Text(context.tr('Device details', 'Chi tiết thiết bị')),
      ),
      body: RemoteView(
        load: () => api.request(path),
        builder: (context, data, reload) {
          final item = object(data);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              WorkspaceHero(
                title: recordTitle(item),
                eyebrow: item['code'] as String?,
                description: item['modelName'] as String? ?? '',
                action: recordStatus(item).isEmpty
                    ? const SizedBox.shrink()
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: StatusPill(status: recordStatus(item)),
                      ),
              ),
              Text(
                context.tr('Device information', 'Thông số thiết bị'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(),
              DetailFields(
                data: item,
                fields: const {
                  'code': ('Code', 'Mã thiết bị'),
                  'name': ('Name', 'Tên'),
                  'serialNumber': ('Serial number', 'Số sê-ri'),
                  'status': ('Status', 'Trạng thái'),
                  'modelName': ('Model', 'Mẫu thiết bị'),
                  'manufacturer': ('Manufacturer', 'Nhà sản xuất'),
                },
              ),
              if (manager) ...[
                FilledButton(
                  onPressed: () async {
                    final body = await editDevice(context, api, initial: item);
                    if (body != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(path, method: 'PUT', body: body),
                        )) {
                      reload();
                    }
                  },
                  child: Text(context.tr('Edit', 'Chỉnh sửa')),
                ),
                TextButton(
                  onPressed: () async {
                    final confirmation = await editRecord(
                      context,
                      title: context.tr('Delete device', 'Xóa thiết bị'),
                      fields: const [
                        FieldSpec(
                          'confirmed',
                          'Confirm deletion of this device',
                          'Xác nhận xóa thiết bị này',
                          kind: FieldKind.toggle,
                        ),
                      ],
                    );
                    if (confirmation != null &&
                        context.mounted &&
                        await runAction(
                          context,
                          () => api.request(path, method: 'DELETE'),
                        ) &&
                        context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(context.tr('Delete', 'Xóa')),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
