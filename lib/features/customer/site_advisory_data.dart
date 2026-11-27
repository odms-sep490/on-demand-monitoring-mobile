import '../../core/api_client.dart';
import '../../core/models.dart';

Future<Json> loadSiteAdvisory(
  ApiClient api, {
  required Json order,
  required Json area,
  required bool confirm,
}) async {
  final result = <String, dynamic>{};
  Future<void> attempt(String key, Future<Object?> Function() action) async {
    try {
      result[key] = await action();
    } catch (error) {
      result['${key}Error'] = '$error';
    }
  }

  final lat = order['latitude'], lon = order['longitude'];
  final req = records(order['deliverables']).isEmpty
      ? <String, dynamic>{}
      : object(records(order['deliverables']).first['requirement']);
  final riskRadius = num.tryParse(
    '${area['radiusM'] ?? order['radiusM'] ?? req['radiusM'] ?? req['radius_m'] ?? ''}',
  );
  if (lat is! num || lon is! num || riskRadius == null) {
    result['riskError'] = 'LOCATION_INCOMPLETE';
  }
  await Future.wait([
    if (lat is num && lon is num && riskRadius != null)
      attempt(
        'risk',
        () => api.request(
          '/api/flight-area-assessment',
          query: {
            'latitude': lat,
            'longitude': lon,
            'radiusMeters': riskRadius,
            'requestedAltitudeAgl': order['altitudeM'],
            'includeOsm': true,
          },
        ),
      ),
    attempt('weather', () async {
      final times = records(await api.request('/api/preferred-times'));
      final slots = times
          .where((e) => e['id'] == order['preferredTimeId'])
          .toList();
      final time = slots.isEmpty ? null : slots.first['startTime'];
      if (time is! String ||
          time.length < 5 ||
          order['preferredDateFrom'] == null ||
          lat is! num ||
          lon is! num) {
        throw const ApiFailure(
          'The order has no complete location and time slot for a forecast.',
        );
      }
      return api.request(
        '/api/weather/forecast',
        query: {
          'latitude': lat,
          'longitude': lon,
          'date': order['preferredDateFrom'],
          'time': time.substring(0, 5),
        },
      );
    }),
    if (confirm)
      attempt(
        'quote',
        () => api.request(
          '/api/pricing/checklist-quote',
          method: 'POST',
          body: {
            'serviceId': order['serviceId'],
            'items': records(order['checklistItems'])
                .map(
                  (e) => {
                    if (e['sourceChecklistId'] != null)
                      'sourceChecklistId': e['sourceChecklistId'],
                    if (e['existingItemId'] != null)
                      'existingItemId': e['existingItemId'],
                    'content': e['contentOverride'] ?? e['content'],
                    if (e['requestedImageCount'] != null)
                      'requestedImageCount': e['requestedImageCount'],
                    if (e['requestedVideoCount'] != null)
                      'requestedVideoCount': e['requestedVideoCount'],
                  },
                )
                .toList(),
            if (area['areaHa'] != null) 'areaHa': area['areaHa'],
            if (order['estimatedLengthM'] is num)
              'lengthKm': (order['estimatedLengthM'] as num) / 1000,
            'altitudeM': order['altitudeM'],
            'occurrences': order['recurrenceType'] == 'NONE'
                ? 1
                : order['recurrenceOccurrences'],
            'resultFormats': order['resultFormats'],
            'permitStatus': order['permitStatus'],
          },
        ),
      ),
  ]);
  return result;
}
