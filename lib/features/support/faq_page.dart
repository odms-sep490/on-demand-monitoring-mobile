import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';

class FaqPage extends ConsumerStatefulWidget {
  const FaqPage({super.key});
  @override
  ConsumerState<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends ConsumerState<FaqPage> {
  String search = '';
  String? category;
  final voted = <String>{};
  final pending = <String>{};

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    return PortalScaffold(
      appBar: AppBar(title: Text(context.tr('FAQ', 'Câu hỏi thường gặp'))),
      body: RemoteView(
        load: () => api.request('/api/support-tickets/faq-articles'),
        builder: (context, data, reload) {
          final articles = records(data);
          final categories = {
            for (final article in articles)
              if (article['category'] is String)
                article['category'] as String:
                    '${article['categoryLabel'] ?? article['category']}',
          };
          final matches = articles
              .where(
                (article) =>
                    (category == null || article['category'] == category) &&
                    "${article['question']} ${article['answer']} ${article['keywords'] ?? ''}"
                        .toLowerCase()
                        .contains(search),
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: context.tr('Search FAQ', 'Tìm câu hỏi'),
                ),
                onChanged: (text) =>
                    setState(() => search = text.trim().toLowerCase()),
              ),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(context.tr('All', 'Tất cả')),
                    selected: category == null,
                    onSelected: (_) => setState(() => category = null),
                  ),
                  for (final entry in categories.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: category == entry.key,
                      onSelected: (_) => setState(() => category = entry.key),
                    ),
                ],
              ),
              if (matches.isEmpty)
                Text(
                  context.tr(
                    'No matching questions.',
                    'Không tìm thấy câu hỏi phù hợp.',
                  ),
                ),
              for (final article in matches)
                Card(
                  child: ExpansionTile(
                    title: Text('${article['question']}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText('${article['answer']}'),
                      ),
                      if (article['articleId'] case final String id)
                        if (voted.contains(id))
                          Text(
                            context.tr(
                              'Thanks for your feedback.',
                              'Cảm ơn bạn đã góp ý.',
                            ),
                          )
                        else
                          Wrap(
                            children: [
                              for (final helpful in [true, false])
                                TextButton(
                                  onPressed: pending.contains(id)
                                      ? null
                                      : () async {
                                          setState(() => pending.add(id));
                                          final success = await runAction(
                                            context,
                                            () => api.request(
                                              '/api/support-tickets/faq-feedback',
                                              method: 'POST',
                                              body: {
                                                'articleId': id,
                                                'articleQuestion':
                                                    article['question'],
                                                'articleCategory':
                                                    article['category'],
                                                'isHelpful': helpful,
                                              },
                                            ),
                                          );
                                          if (!mounted) return;
                                          setState(() {
                                            pending.remove(id);
                                            if (success) voted.add(id);
                                          });
                                        },
                                  child: Text(
                                    helpful
                                        ? context.tr('Helpful', 'Hữu ích')
                                        : context.tr(
                                            'Not helpful',
                                            'Chưa hữu ích',
                                          ),
                                  ),
                                ),
                            ],
                          ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
