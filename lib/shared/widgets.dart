import 'package:material_ui/material_ui.dart';

import '../core/models.dart';
import 'strings.dart';
import 'mobile_ui.dart';

class RemoteView extends StatefulWidget {
  const RemoteView({super.key, required this.load, required this.builder});
  final Future<Object?> Function() load;
  final Widget Function(BuildContext, Object?, VoidCallback) builder;
  @override
  State<RemoteView> createState() => _RemoteViewState();
}

class _RemoteViewState extends State<RemoteView> {
  late Future<Object?> future = widget.load();
  void reload() => setState(() => future = widget.load());
  @override
  Widget build(BuildContext context) => FutureBuilder<Object?>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 16),
                Text('${snapshot.error}', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: reload,
                  child: Text(context.tr('Retry', 'Thử lại')),
                ),
              ],
            ),
          ),
        );
      }
      return widget.builder(context, snapshot.data, reload);
    },
  );
}

class RecordList extends StatefulWidget {
  const RecordList({
    super.key,
    required this.items,
    required this.refresh,
    this.onTap,
  });
  final List<Json> items;
  final VoidCallback refresh;
  final void Function(Json)? onTap;
  @override
  State<RecordList> createState() => _RecordListState();
}

class _RecordListState extends State<RecordList> {
  String search = '';
  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where(
          (e) => '${recordTitle(e)} ${recordStatus(e)}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.tr('Search', 'Tìm kiếm'),
            ),
            onChanged: (value) => setState(() => search = value),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => widget.refresh(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: items.isEmpty ? 1 : items.length,
              itemBuilder: (context, index) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text(
                      context.tr('No records found.', 'Chưa có dữ liệu.'),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final item = items[index];
                return DomainCard(
                  item: item,
                  onTap: widget.onTap == null
                      ? null
                      : () => widget.onTap!(item),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class DetailFields extends StatelessWidget {
  const DetailFields({super.key, required this.data, required this.fields});
  final Json data;

  /// Key -> bilingual display label, deliberately excludes technical fields.
  final Map<String, (String, String)> fields;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final entry in fields.entries)
        if (data[entry.key] != null && '${data[entry.key]}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(entry.value.$1, entry.value.$2),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  data[entry.key] is List
                      ? (data[entry.key] as List).join(', ')
                      : '${data[entry.key]}',
                ),
              ],
            ),
          ),
    ],
  );
}

Future<bool> runAction(
  BuildContext context,
  Future<Object?> Function() action,
) async {
  try {
    await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Saved successfully.', 'Đã lưu thành công.'),
          ),
        ),
      );
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
    return false;
  }
}
