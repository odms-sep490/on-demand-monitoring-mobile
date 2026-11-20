import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odms_mobile/core/api_client.dart';
import 'package:odms_mobile/core/models.dart';
import 'package:odms_mobile/features/customer/order_draft.dart';
import 'package:odms_mobile/shared/coverage_geometry.dart';

import 'api_client_test.dart' show MemorySecrets;

void main() {
  test('circle and rectangle use valid GeoJSON-compatible boundaries', () {
    final circle = circleBoundary(const LatLng(10.7, 106.6), 100);
    expect(circle.length, 64);
    expect(validCoverage(circle), true);
    expect(coverageAreaM2(circle), closeTo(math.pi * 10000, 100));
    expect(
      validCoverage(
        rectangleBoundary(const LatLng(10, 106), const LatLng(10.001, 106.001)),
      ),
      true,
    );
    expect(
      validCoverage(
        rectangleBoundary(const LatLng(10, 106), const LatLng(10, 107)),
      ),
      false,
    );
  });
  test('crossing polygon boundaries cannot be confirmed', () {
    expect(
      validCoverage(const [
        LatLng(10, 106),
        LatLng(10.002, 106.002),
        LatLng(10, 106.002),
        LatLng(10.002, 106),
      ]),
      false,
    );
  });
  test('GeoJSON and KML imports derive centre, radius and line length', () {
    final json = parseAreaFile(
      'site.geojson',
      '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[[106,10],[106.002,10.002]]}}]}',
    );
    final kml = parseAreaFile(
      'site.kml',
      '<kml><Placemark><LineString><coordinates>106,10,0 106.002,10.002,0</coordinates></LineString></Placemark></kml>',
    );
    expect(json, isNotNull);
    expect(kml, isNotNull);
    expect(json!.center.latitude, closeTo(10.001, 1e-8));
    expect(json.center.longitude, closeTo(106.001, 1e-8));
    expect(json.radiusM, kml!.radiusM);
    expect(json.lengthM, greaterThan(300));
    expect(parseAreaFile('bad.json', 'not-json'), isNull);
    expect(
      parseAreaFile('bad.geojson', '{"type":"Point","coordinates":[999,999]}'),
      isNull,
    );
  });
  test(
    'order DTO carries imported geometry metadata only inside deliverables',
    () {
      final payload = OrderDraft(
        service: {'serviceId': 'service'},
        details: {
          'title': 'Inspect site',
          'dataRetentionDays': '90',
          'deliverableIds': ['photo'],
          'recurrenceType': 'NONE',
          'recurrenceOccurrences': 9,
        },
        area: {
          'latitude': 10.0,
          'longitude': 106.0,
          'coverageArea': {'type': 'Polygon'},
          'radiusM': 200,
          'coverageAreaShape': 'CIRCLE',
          'areaHa': 2,
          'areaFiles': [
            {'fileName': 'site.kml'},
          ],
        },
        compliance: {'permitStatus': 'NONE', 'termsAccepted': true},
        checklist: [
          {
            'contentOverride': 'Inspect roof',
            'minimumEvidenceCount': 1,
            'requiredEvidenceType': 'IMAGE',
          },
        ],
      ).toRequestJson();
      expect(payload['dataRetentionDays'], 90);
      expect(payload['checklistItems'], isNotEmpty);
      expect(payload.containsKey('deliverableIds'), false);
      expect(payload.containsKey('radiusM'), false);
      expect(payload.containsKey('areaHa'), false);
      expect(payload.containsKey('recurrenceOccurrences'), false);
      final requirement = object(
        records(payload['deliverables']).single['requirement'],
      );
      expect(requirement['radiusM'], 200);
      expect(requirement['estimatedAreaHa'], 2);
      expect(records(requirement['areaFiles']).single['fileName'], 'site.kml');
    },
  );
  test(
    'command identifiers match backend UUID DTOs and survive a retry',
    () async {
      final api = ApiClient('https://api.example', MemorySecrets());
      final id = api.commandId('/api/order/result', {'version': 1});
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id),
        true,
      );
      expect(api.commandId('/api/order/result', {'version': 1}), id);
      expect(api.commandId('/api/order/result', {'version': 2}), isNot(id));
      await api.clearSession();
      expect(api.commandId('/api/order/result', {'version': 1}), isNot(id));
      api.dio.close();
    },
  );
}
