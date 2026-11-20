import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../core/models.dart';

const earthRadiusM = 6371008.8;
const radians = math.pi / 180;

double distanceMeters(LatLng a, LatLng b) {
  final dLat = (b.latitude - a.latitude) * radians,
      dLon = (b.longitude - a.longitude) * radians;
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.latitude * radians) *
          math.cos(b.latitude * radians) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

List<LatLng> circleBoundary(LatLng center, double radiusM) =>
    List.generate(64, (i) {
      final angle = -2 * math.pi * i / 64, distance = radiusM / earthRadiusM;
      final lat = center.latitude * radians, lon = center.longitude * radians;
      final nextLat = math.asin(
        math.sin(lat) * math.cos(distance) +
            math.cos(lat) * math.sin(distance) * math.cos(angle),
      );
      final nextLon =
          lon +
          math.atan2(
            math.sin(angle) * math.sin(distance) * math.cos(lat),
            math.cos(distance) - math.sin(lat) * math.sin(nextLat),
          );
      return LatLng(nextLat / radians, nextLon / radians);
    });

List<LatLng> rectangleBoundary(LatLng a, LatLng b) => [
  LatLng(math.min(a.latitude, b.latitude), math.min(a.longitude, b.longitude)),
  LatLng(math.min(a.latitude, b.latitude), math.max(a.longitude, b.longitude)),
  LatLng(math.max(a.latitude, b.latitude), math.max(a.longitude, b.longitude)),
  LatLng(math.max(a.latitude, b.latitude), math.min(a.longitude, b.longitude)),
];

double coverageAreaM2(List<LatLng> points) {
  if (points.length < 3) return 0;
  var sum = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i], b = points[(i + 1) % points.length];
    sum +=
        (b.longitude - a.longitude) *
        radians *
        (2 + math.sin(a.latitude * radians) + math.sin(b.latitude * radians));
  }
  return (sum * earthRadiusM * earthRadiusM / 2).abs();
}

bool validCoverage(List<LatLng> input) {
  final points = [...input];
  if (points.length > 1 && points.first == points.last) points.removeLast();
  if (points.length < 3 ||
      points.toSet().length < 3 ||
      coverageAreaM2(points) < 1) {
    return false;
  }
  double cross(LatLng a, LatLng b, LatLng c) =>
      (b.longitude - a.longitude) * (c.latitude - a.latitude) -
      (b.latitude - a.latitude) * (c.longitude - a.longitude);
  bool between(double a, double b, double c) =>
      b >= math.min(a, c) - 1e-12 && b <= math.max(a, c) + 1e-12;
  bool onLine(LatLng a, LatLng b, LatLng c) =>
      between(a.longitude, b.longitude, c.longitude) &&
      between(a.latitude, b.latitude, c.latitude);
  bool intersects(LatLng a, LatLng b, LatLng c, LatLng d) {
    final x = cross(a, b, c),
        y = cross(a, b, d),
        z = cross(c, d, a),
        w = cross(c, d, b);
    if (x * y < 0 && z * w < 0) return true;
    return x.abs() < 1e-12 && onLine(a, c, b) ||
        y.abs() < 1e-12 && onLine(a, d, b) ||
        z.abs() < 1e-12 && onLine(c, a, d) ||
        w.abs() < 1e-12 && onLine(c, b, d);
  }

  for (var i = 0; i < points.length; i++) {
    for (var j = i + 1; j < points.length; j++) {
      final nextI = (i + 1) % points.length, nextJ = (j + 1) % points.length;
      if (nextI == j || nextJ == i) continue;
      if (intersects(points[i], points[nextI], points[j], points[nextJ])) {
        return false;
      }
    }
  }
  return true;
}

class ImportedArea {
  const ImportedArea(this.center, this.radiusM, this.lengthM);
  final LatLng center;
  final double radiusM;
  final double? lengthM;
}

/// Mirrors the website's KML/GeoJSON importer: derive a centre, covering radius
/// (100–1500 m, in 50 m steps) and optional total line length.
ImportedArea? parseAreaFile(String name, String text) {
  final coordinates = <LatLng>[], lines = <List<LatLng>>[];
  LatLng? coordinate(Object? value) {
    if (value is! List ||
        value.length < 2 ||
        value[0] is! num ||
        value[1] is! num) {
      return null;
    }
    final lon = (value[0] as num).toDouble(),
        lat = (value[1] as num).toDouble();
    return lon.isFinite && lat.isFinite && lon.abs() <= 180 && lat.abs() <= 90
        ? LatLng(lat, lon)
        : null;
  }

  void walkCoordinates(Object? value) {
    final point = coordinate(value);
    if (point != null) {
      coordinates.add(point);
    } else if (value is List) {
      for (final child in value) {
        walkCoordinates(child);
      }
    }
  }

  void geometry(Json item) {
    if (item['type'] == 'GeometryCollection') {
      for (final child in records(item['geometries'])) {
        geometry(child);
      }
      return;
    }
    walkCoordinates(item['coordinates']);
    if (item['type'] == 'LineString') {
      lines.add(
        (item['coordinates'] as List? ?? [])
            .map(coordinate)
            .whereType<LatLng>()
            .toList(),
      );
    }
    if (item['type'] == 'MultiLineString') {
      for (final line in item['coordinates'] as List? ?? []) {
        if (line is List) {
          lines.add(line.map(coordinate).whereType<LatLng>().toList());
        }
      }
    }
  }

  void visit(Json item) {
    if (item['type'] == 'FeatureCollection') {
      for (final child in records(item['features'])) {
        visit(child);
      }
    } else if (item['type'] == 'Feature') {
      geometry(object(item['geometry']));
    } else {
      geometry(item);
    }
  }

  final lower = name.toLowerCase();
  if (lower.endsWith('.kml')) {
    if (!RegExp(r'<kml[\s>]', caseSensitive: false).hasMatch(text)) return null;
    List<LatLng> parse(String value) => value
        .trim()
        .split(RegExp(r'\s+'))
        .map((tuple) => coordinate(tuple.split(',').map(num.tryParse).toList()))
        .whereType<LatLng>()
        .toList();
    for (final match in RegExp(
      r'<coordinates[^>]*>(.*?)</coordinates>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(text)) {
      coordinates.addAll(parse(match[1]!));
    }
    for (final match in RegExp(
      r'<LineString[^>]*>.*?<coordinates[^>]*>(.*?)</coordinates>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(text)) {
      lines.add(parse(match[1]!));
    }
  } else if (lower.endsWith('.geojson') || lower.endsWith('.json')) {
    try {
      visit(object(jsonDecode(text)));
    } on FormatException {
      return null;
    }
  } else {
    return null;
  }
  if (coordinates.isEmpty) return null;
  final center = LatLng(
    (coordinates.map((p) => p.latitude).reduce(math.min) +
            coordinates.map((p) => p.latitude).reduce(math.max)) /
        2,
    (coordinates.map((p) => p.longitude).reduce(math.min) +
            coordinates.map((p) => p.longitude).reduce(math.max)) /
        2,
  );
  final farthest = coordinates
      .map((point) => distanceMeters(center, point))
      .reduce(math.max);
  var length = 0.0;
  for (final line in lines) {
    for (var i = 1; i < line.length; i++) {
      length += distanceMeters(line[i - 1], line[i]);
    }
  }
  return ImportedArea(
    center,
    ((farthest / 50).ceil() * 50).clamp(100, 1500).toDouble(),
    length > 0 ? length.roundToDouble() : null,
  );
}
