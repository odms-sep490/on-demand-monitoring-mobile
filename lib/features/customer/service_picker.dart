import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/config.dart';
import '../../shared/strings.dart';

class CustomerServicePicker extends StatefulWidget {
  const CustomerServicePicker({super.key, required this.services});
  final List<Json> services;

  @override
  State<CustomerServicePicker> createState() => _CustomerServicePickerState();
}

class _CustomerServicePickerState extends State<CustomerServicePicker> {
  String? selection, purpose;
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final otherPurpose = TextEditingController();

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    otherPurpose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('New request', 'Tạo yêu cầu'))),
      body: Form(
        key: form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  context.tr(
                    'No services available.',
                    'Chưa có dịch vụ khả dụng.',
                  ),
                ),
              for (final service in widget.services)
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
                                child: _ServiceArtwork(service: service),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      recordTitle(service),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
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
              const SizedBox(height: 10),
              TextFormField(
                controller: title,
                decoration: InputDecoration(
                  labelText: context.tr('Request title', 'Tiêu đề yêu cầu'),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.tr(
                        'Enter a request title.',
                        'Nhập tiêu đề yêu cầu.',
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: purpose,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr(
                    'Monitoring purpose',
                    'Mục đích giám sát',
                  ),
                ),
                items: [
                  for (final entry in {
                    'SURVEY_MONITORING': context.tr('Survey', 'Khảo sát'),
                    'AGRICULTURE': context.tr('Agriculture', 'Nông nghiệp'),
                    'CONSTRUCTION_MONITORING': context.tr(
                      'Construction',
                      'Công trình',
                    ),
                    'INDUSTRIAL_INSPECTION': context.tr(
                      'Industrial inspection',
                      'Kiểm tra công nghiệp',
                    ),
                    'AREA_MONITORING': context.tr(
                      'Area monitoring',
                      'Giám sát khu vực',
                    ),
                    'FOREST_MONITORING': context.tr(
                      'Forest monitoring',
                      'Giám sát rừng',
                    ),
                    'OTHER': context.tr('Other', 'Khác'),
                  }.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => setState(() => purpose = value),
                validator: (value) => value == null
                    ? context.tr('Choose a purpose.', 'Chọn mục đích giám sát.')
                    : null,
              ),
              if (purpose == 'OTHER') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: otherPurpose,
                  decoration: InputDecoration(
                    labelText: context.tr(
                      'Describe the purpose',
                      'Mô tả mục đích khác',
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.tr(
                          'Enter a purpose.',
                          'Nhập mục đích giám sát.',
                        )
                      : null,
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: description,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.tr('Description', 'Mô tả yêu cầu'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: FilledButton.icon(
          onPressed: selection == null
              ? null
              : () {
                  if (form.currentState?.validate() != true) return;
                  Navigator.pop<Json>(context, {
                    'serviceId': selection,
                    'title': title.text.trim(),
                    'flightPurpose': purpose,
                    if (purpose == 'OTHER')
                      'otherFlightPurpose': otherPurpose.text.trim(),
                    if (description.text.trim().isNotEmpty)
                      'description': description.text.trim(),
                  });
                },
          label: Text(context.tr('Continue', 'Tiếp tục')),
          icon: const Icon(Icons.arrow_forward),
          iconAlignment: IconAlignment.end,
        ),
      ),
    );
  }
}

class _ServiceArtwork extends StatelessWidget {
  const _ServiceArtwork({required this.service});
  final Json service;

  @override
  Widget build(BuildContext context) {
    final details = "${recordTitle(service)} ${service['description'] ?? ''}"
        .toLowerCase();
    final fallback = switch (details) {
      _
          when RegExp(
            r'warehouse|factory|industrial|construction|building|nhà xưởng|nhà máy|công trình|xưởng',
          ).hasMatch(details) =>
        'construction-640',
      _ when RegExp(r'forest|woodland|lâm nghiệp|rừng').hasMatch(details) =>
        'highland-overview',
      _
          when RegExp(r'area|region|urban|khu vực|khu dân cư|đô thị')
              .hasMatch(details) =>
        'infrastructure-640',
      _ => 'landscape-640',
    };
    Widget local() =>
        Image.asset('assets/images/$fallback.webp', fit: BoxFit.cover);
    final supplied = service['imageUrl'] as String?;
    final base = Uri.tryParse(AppConfig.apiBaseUrl);
    final url = supplied == null || supplied.trim().isEmpty
        ? null
        : base?.resolve(supplied);
    return SizedBox(
      width: 86,
      height: 74,
      child: url != null && (url.scheme == 'http' || url.scheme == 'https')
          ? Image.network(
              url.toString(),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => local(),
            )
          : local(),
    );
  }
}
