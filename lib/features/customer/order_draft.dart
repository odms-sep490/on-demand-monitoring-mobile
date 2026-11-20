import '../../core/models.dart';

/// A confirmed customer draft. Map-only drawing/import metadata belongs in
/// deliverable requirements, not in the backend OrderCreateRequest root.
class OrderDraft {
  OrderDraft({
    required Json service,
    required Json details,
    required Json area,
    required Json compliance,
    required List<Json> checklist,
  }) : service = Map.unmodifiable(service),
       details = Map.unmodifiable(details),
       area = Map.unmodifiable(area),
       compliance = Map.unmodifiable(compliance),
       checklist = List.unmodifiable(checklist);
  final Json service, details, area, compliance;
  final List<Json> checklist;

  Json toRequestJson() {
    final requirement = {
      for (final key in [
        'radiusM',
        'coverageAreaShape',
        'coverageAreaCenter',
        'areaFiles',
        'customerAttachments',
        'otherFlightPurpose',
        'otherMonitoringRelationship',
      ])
        if (area[key] != null || details[key] != null)
          key: area[key] ?? details[key],
      if (area['areaHa'] != null) 'estimatedAreaHa': area['areaHa'],
    };
    final body = <String, dynamic>{
      ...compliance,
      ...service,
      ...details,
      'longitude': area['longitude'],
      'latitude': area['latitude'],
      'coverageArea': area['coverageArea'],
      if (area['estimatedLengthM'] != null)
        'estimatedLengthM': area['estimatedLengthM'],
      'dataRetentionDays': num.parse('${details['dataRetentionDays']}').toInt(),
      'checklistItems': checklist,
      'deliverables': (details['deliverableIds'] as List)
          .map(
            (id) => {
              'deliverableTypeId': id,
              'requirement': {...requirement},
            },
          )
          .toList(),
    };
    for (final key in [
      'deliverableIds',
      'otherFlightPurpose',
      'otherMonitoringRelationship',
      'customerAttachments',
    ]) {
      body.remove(key);
    }
    if (body['recurrenceType'] == 'NONE') body.remove('recurrenceOccurrences');
    return body;
  }
}
