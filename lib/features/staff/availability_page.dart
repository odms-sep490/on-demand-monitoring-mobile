import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class AvailabilityPage extends ConsumerStatefulWidget {
  const AvailabilityPage({super.key});
  @override
  ConsumerState<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends ConsumerState<AvailabilityPage> {
  DateTime week = DateTime.now();
  String get date =>
      '${week.year}-${week.month.toString().padLeft(2, '0')}-${week.day.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    Future<void> edit({Json initial = const {}}) async {
      final body = await editRecord(
        context,
        title: context.tr('Busy session', 'Buổi bận'),
        initial: initial,
        fields: const [
          FieldSpec(
            'date',
            'Date (Vietnam)',
            'Ngày (Việt Nam)',
            kind: FieldKind.date,
          ),
          FieldSpec(
            'session',
            'Session',
            'Buổi',
            kind: FieldKind.choice,
            options: {
              'MORNING': 'Morning / Sáng',
              'AFTERNOON': 'Afternoon / Chiều',
              'EVENING': 'Evening / Tối',
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
      if (body != null &&
          context.mounted &&
          await runAction(
            context,
            () => api.request(
              initial.isEmpty
                  ? '/api/busy-schedules'
                  : '/api/busy-schedules/${segment('${initial['id']}')}',
              method: initial.isEmpty ? 'POST' : 'PUT',
              body: body,
            ),
          ) &&
          mounted) {
        setState(() {});
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Availability', 'Lịch bận'))),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(
                  () => week = week.subtract(const Duration(days: 7)),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(date),
              IconButton(
                onPressed: () =>
                    setState(() => week = week.add(const Duration(days: 7))),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Expanded(
            child: RemoteView(
              key: ValueKey('$date-${DateTime.now().microsecondsSinceEpoch}'),
              load: () =>
                  api.request('/api/busy-schedules/me', query: {'date': date}),
              builder: (context, data, reload) {
                final schedule = object(data);
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('${schedule['weekStart']} – ${schedule['weekEnd']}'),
                    const SizedBox(height: 12),
                    Text(
                      context.tr(
                        '${schedule['remainingSessions']} busy sessions remaining this week',
                        'Còn ${schedule['remainingSessions']} buổi đăng ký bận trong tuần',
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final session in records(schedule['items']))
                      Card(
                        child: ListTile(
                          title: Text(
                            '${session['date']} · ${session['session']}',
                          ),
                          subtitle: Text('${session['notes'] ?? ''}'),
                          onTap: () => edit(initial: session),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    context.tr(
                                      'Remove busy session?',
                                      'Xóa buổi bận?',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(
                                        context.tr('Back', 'Quay lại'),
                                      ),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(context.tr('Remove', 'Xóa')),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true &&
                                  context.mounted &&
                                  await runAction(
                                    context,
                                    () => api.request(
                                      '/api/busy-schedules/${segment('${session['id']}')}',
                                      method: 'DELETE',
                                    ),
                                  )) {
                                reload();
                              }
                            },
                          ),
                        ),
                      ),
                    if (records(schedule['items']).isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.tr(
                            'No busy sessions registered.',
                            'Chưa đăng ký buổi bận.',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: edit,
        child: const Icon(Icons.add),
      ),
    );
  }
}
