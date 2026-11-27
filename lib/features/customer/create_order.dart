import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../shared/area_picker.dart';
import '../../shared/editor.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import 'checklist_editor.dart';
import 'order_compliance.dart';
import 'order_confirmation.dart';
import 'order_draft.dart';
import 'order_step_forms.dart';
import 'service_picker.dart';

Future<bool> createOrder(BuildContext context, ApiClient api) async {
  try {
    return await _createOrder(context, api);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
    return false;
  }
}

Future<bool> _createOrder(BuildContext context, ApiClient api) async {
  final services = records(
    await api.request('/api/services', query: {'activeOnly': true}),
  ).where((row) => row['id'] is String).toList();
  if (!context.mounted) return false;
  final service = await Navigator.of(context).push<Json>(
    MaterialPageRoute(
      builder: (_) => CustomerServicePicker(services: services),
    ),
  );
  if (service == null || !context.mounted) return false;
  final serviceId = service['serviceId'] as String;
  final location = await editRecord(
    context,
    title: context.tr('2. Monitoring location', '2. Vị trí & vùng giám sát'),
    fields: [const FieldSpec('address', 'Site address', 'Địa chỉ giám sát')],
  );
  if (location == null || !context.mounted) return false;
  final area = await Navigator.push<Json>(
    context,
    MaterialPageRoute(
      builder: (_) => AreaPicker(initialAddress: location['address'] as String),
    ),
  );
  if (area == null || !context.mounted) return false;
  final templates = records(
    await api.request('/api/services/${segment(serviceId)}/checklists'),
  );
  if (!context.mounted) return false;
  final selected = await Navigator.push<List<Json>>(
    context,
    MaterialPageRoute(
      builder: (_) => CustomerChecklistEditor(
        returnSelection: true,
        order: {
          'serviceId': serviceId,
          'checklistItems': templates
              .where(
                (e) =>
                    e['serviceActive'] != false &&
                    e['checklistActive'] != false,
              )
              .map(
                (e) => {
                  'sourceChecklistId': e['checklistId'],
                  'sourceChecklistVersion': e['checklistVersion'],
                  'content': e['content'],
                  'required': e['required'] ?? false,
                  'minimumEvidenceCount': e['minimumEvidenceCount'],
                  'requiredEvidenceType': e['requiredEvidenceType'],
                  'requestedImageCount': e['includedImageCount'] ?? 0,
                  'requestedVideoCount': e['includedVideoCount'] ?? 0,
                },
              )
              .toList(),
        },
      ),
    ),
  );
  if (selected == null || !context.mounted) return false;
  final site = await collectSiteDetails(context);
  if (site == null || !context.mounted) return false;
  final compliance = await collectOrderCompliance(
    context,
    includeDeliveryOptions: false,
  );
  if (compliance == null || !context.mounted) return false;
  final schedule = await collectOrderSchedule(context, api);
  if (schedule == null || !context.mounted) return false;
  final delivery = await collectDeliveryPreferences(context, api, serviceId);
  if (delivery == null || !context.mounted) return false;
  final details = {
    ...service,
    ...location,
    if (area['normalizedAddress'] case final String address) 'address': address,
    ...site,
    ...schedule,
    ...delivery,
  };
  final body = OrderDraft(
    service: {'serviceId': serviceId},
    details: details,
    area: area,
    compliance: compliance,
    checklist: selected,
  ).toRequestJson();
  final confirmed = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => SiteAdvisoryPage(order: body, area: area, confirm: true),
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  return runAction(
    context,
    () => api.request('/api/orders', method: 'POST', body: body),
  );
}
