import '../../shared/portal_scaffold.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

Json checklistUpdateItem(Json row) {
  final images = (row['requestedImageCount'] as num?)?.toInt() ?? 0;
  final videos = (row['requestedVideoCount'] as num?)?.toInt() ?? 0;
  return {
    if (row['id'] != null) 'existingItemId': row['id'],
    if (row['id'] == null && row['sourceChecklistId'] != null) ...{
      'sourceChecklistId': row['sourceChecklistId'],
      'expectedChecklistVersion': row['sourceChecklistVersion'],
    },
    'contentOverride': row['content'],
    if (images + videos > 0) ...{
      'requestedImageCount': images,
      'requestedVideoCount': videos,
    } else ...{
      'minimumEvidenceCount': row['minimumEvidenceCount'] ?? 1,
      'requiredEvidenceType': row['requiredEvidenceType'] ?? 'IMAGE',
    },
  };
}

class CustomerChecklistEditor extends ConsumerStatefulWidget {
  const CustomerChecklistEditor({super.key, required this.order});
  final Json order;
  @override
  ConsumerState<CustomerChecklistEditor> createState() =>
      _CustomerChecklistEditorState();
}

class _CustomerChecklistEditorState
    extends ConsumerState<CustomerChecklistEditor> {
  late List<Json> rows = records(widget.order['checklistItems'])
      .map((item) => {...item})
      .toList();
  bool saving = false;
  Future<void> edit({Json? row}) async {
    final body = await editRecord(
      context,
      title: context.tr('Monitoring requirement', 'Yêu cầu giám sát'),
      initial: row ?? {},
      fields: [
        const FieldSpec(
          'content',
          'Requirement',
          'Nội dung yêu cầu',
          kind: FieldKind.multiline,
        ),
        FieldSpec(
          'requestedImageCount',
          'Requested photos',
          'Số ảnh yêu cầu',
          kind: FieldKind.number,
          min: 0,
          initial: row?['requestedImageCount'] ?? 0,
        ),
        FieldSpec(
          'requestedVideoCount',
          'Requested videos',
          'Số video yêu cầu',
          kind: FieldKind.number,
          min: 0,
          initial: row?['requestedVideoCount'] ?? 0,
        ),
      ],
    );
    if (body == null || !mounted) return;
    setState(() {
      if (row == null) {
        rows.add(body);
      } else {
        row.addAll(body);
      }
    });
  }

  Future<void> addCatalog() async {
    try {
      final catalog = records(
        await ref.read(apiProvider).request('/api/checklists/catalog'),
      );
      if (!mounted) return;
      final body = await editRecord(
        context,
        title: context.tr('Add from catalogue', 'Thêm từ danh mục'),
        fields: [
          FieldSpec(
            'ids',
            'Requirements',
            'Yêu cầu',
            kind: FieldKind.multiChoice,
            options: {
              for (final item in catalog.where(
                (e) => !rows.any((r) => r['sourceChecklistId'] == e['id']),
              ))
                '${item['id']}': '${item['content']}',
            },
          ),
        ],
      );
      if (body == null || !mounted) return;
      setState(() {
        for (final item in catalog.where(
          (e) => (body['ids'] as List).contains(e['id']),
        )) {
          rows.add({
            'content': item['content'],
            'sourceChecklistId': item['id'],
            'sourceChecklistVersion': item['version'],
            'requestedImageCount': item['includedImageCount'] ?? 0,
            'requestedVideoCount': item['includedVideoCount'] ?? 0,
          });
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PortalScaffold(
    appBar: AppBar(
      title: Text(context.tr('Edit checklist', 'Chỉnh sửa hạng mục')),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final row in rows)
          Card(
            child: ListTile(
              title: Text('${row['content']}'),
              subtitle: Text(
                context.tr(
                  '${row['requestedImageCount'] ?? 0} photos · ${row['requestedVideoCount'] ?? 0} videos',
                  '${row['requestedImageCount'] ?? 0} ảnh · ${row['requestedVideoCount'] ?? 0} video',
                ),
              ),
              onTap: saving ? null : () => edit(row: row),
              trailing: row['required'] == true
                  ? const Icon(Icons.lock_outline)
                  : IconButton(
                      onPressed: saving
                          ? null
                          : () => setState(() => rows.remove(row)),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
            ),
          ),
        OutlinedButton(
          onPressed: saving ? null : addCatalog,
          child: Text(context.tr('Add from catalogue', 'Thêm từ danh mục')),
        ),
        OutlinedButton(
          onPressed: saving ? null : edit,
          child: Text(
            context.tr('Add custom requirement', 'Thêm yêu cầu riêng'),
          ),
        ),
        FilledButton(
          onPressed: saving || rows.isEmpty
              ? null
              : () async {
                  setState(() => saving = true);
                  final saved = await runAction(
                    context,
                    () => ref
                        .read(apiProvider)
                        .request(
                          '/api/orders/${segment('${widget.order['id']}')}/checklist',
                          method: 'PUT',
                          body: {
                            'expectedRevision':
                                widget.order['checklistRevision'],
                            'items': rows.map(checklistUpdateItem).toList(),
                          },
                        ),
                  );
                  if (mounted) {
                    setState(() => saving = false);
                    if (saved && context.mounted) Navigator.pop(context, true);
                  }
                },
          child: Text(context.tr('Save checklist', 'Lưu hạng mục')),
        ),
      ],
    ),
  );
}
