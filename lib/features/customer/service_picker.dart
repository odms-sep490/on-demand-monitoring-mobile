import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../shared/strings.dart';

class CustomerServicePicker extends StatefulWidget {
  const CustomerServicePicker({super.key, required this.services});
  final List<Json> services;

  @override
  State<CustomerServicePicker> createState() => _CustomerServicePickerState();
}

class _CustomerServicePickerState extends State<CustomerServicePicker> {
  static const images = [
    'construction-640',
    'infrastructure-640',
    'landscape-640',
    'highland-overview',
  ];
  String? selection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('New request', 'Tạo yêu cầu'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          LinearProgressIndicator(
            value: 1 / 6,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('Service & purpose', 'Dịch vụ & mục tiêu'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'Choose the service that fits your site.',
              'Chọn loại giám sát phù hợp với địa điểm.',
            ),
          ),
          const SizedBox(height: 16),
          if (widget.services.isEmpty)
            Text(
              context.tr('No services available.', 'Chưa có dịch vụ khả dụng.'),
            ),
          for (final (index, service) in widget.services.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Semantics(
                selected: selection == service['id'],
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () =>
                        setState(() => selection = service['id'] as String),
                    child: AnimatedContainer(
                      duration: duration,
                      decoration: BoxDecoration(
                        color: selection == service['id']
                            ? colors.primaryContainer
                            : colors.surfaceContainerLow,
                        border: Border.all(
                          color: selection == service['id']
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/images/${images[index % images.length]}.webp',
                              width: 86,
                              height: 74,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recordTitle(service),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if (service['description']
                                    case final String description
                                    when description.isNotEmpty)
                                  Text(
                                    description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            selection == service['id']
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: selection == service['id']
                                ? colors.primary
                                : colors.outline,
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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: FilledButton.icon(
          onPressed: selection == null
              ? null
              : () => Navigator.pop(context, selection),
          label: Text(context.tr('Continue', 'Tiếp tục')),
          icon: const Icon(Icons.arrow_forward),
          iconAlignment: IconAlignment.end,
        ),
      ),
    );
  }
}
