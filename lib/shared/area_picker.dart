import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';

import '../core/models.dart';
import '../core/providers.dart';
import 'coverage_geometry.dart';
import 'editor.dart';
import 'files.dart';
import 'strings.dart';

Json polygonPayload(List<LatLng> input) {
  final points = [...input];
  if (points.length > 1 && points.first == points.last) points.removeLast();
  if (!validCoverage(points)) {
    throw const FormatException(
      'Select a valid area of at least 1 m² with no crossing boundaries.',
    );
  }
  return {
    'type': 'Polygon',
    'coordinates': [
      [...points, points.first].map((p) => [p.longitude, p.latitude]).toList(),
    ],
  };
}

class AreaPicker extends ConsumerStatefulWidget {
  const AreaPicker({super.key, this.initialAddress});
  final String? initialAddress;
  @override
  ConsumerState<AreaPicker> createState() => _AreaPickerState();
}

class _AreaPickerState extends ConsumerState<AreaPicker> {
  final points = <LatLng>[], attachments = <Json>[];
  late final address = TextEditingController(text: widget.initialAddress);
  final map = MapController();
  String shape = 'POLYGON';
  LatLng? center;
  double radius = 250;
  double? length;
  bool busy = false;
  String? place;
  List<LatLng> get boundary => shape == 'CIRCLE'
      ? center == null
            ? []
            : circleBoundary(center!, radius)
      : shape == 'RECTANGLE'
      ? points.length < 2
            ? []
            : rectangleBoundary(points[0], points[1])
      : points;
  @override
  void dispose() {
    address.dispose();
    map.dispose();
    super.dispose();
  }

  void tap(LatLng point) => setState(() {
    if (shape == 'CIRCLE') {
      center = point;
    } else if (shape == 'RECTANGLE') {
      if (points.length >= 2) points.clear();
      points.add(point);
    } else {
      points.add(point);
    }
  });
  Future<void> search() async {
    if (address.text.trim().isEmpty || busy) return;
    setState(() => busy = true);
    try {
      final result = object(
        await ref
            .read(apiProvider)
            .request(
              '/api/geocoding/search',
              query: {'q': address.text.trim()},
            ),
      );
      if (!mounted) return;
      final lat = (result['latitude'] as num).toDouble(),
          lon = (result['longitude'] as num).toDouble();
      map.move(LatLng(lat, lon), 16);
      setState(() => place = result['displayName'] as String?);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> importArea() async {
    try {
      final files = await pickOneFile(
        type: FileType.custom,
        allowedExtensions: ['kml', 'geojson', 'json'],
      );
      if (files.isEmpty || files.single.path == null || !mounted) return;
      final file = File(files.single.path!);
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('Choose an area file smaller than 5 MB.');
      }
      final bytes = await file.readAsBytes(), name = files.single.name;
      final parsed = parseAreaFile(name, utf8.decode(bytes));
      if (parsed == null) {
        throw const FormatException(
          'No valid coordinates found in the KML/GeoJSON file.',
        );
      }
      if (!mounted) return;
      setState(() {
        shape = 'CIRCLE';
        center = parsed.center;
        radius = parsed.radiusM;
        length = parsed.lengthM;
        points.clear();
        final mime = name.toLowerCase().endsWith('.kml')
            ? 'application/vnd.google-earth.kml+xml'
            : 'application/geo+json';
        attachments.add({
          'id': newRequestId(),
          'fileName': name,
          'contentType': mime,
          'sizeBytes': bytes.length,
          'dataUrl': 'data:$mime;base64,${base64Encode(bytes)}',
        });
      });
      map.move(parsed.center, 15);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> coordinates() async {
    final body = await editRecord(
      context,
      title: context.tr('Go to coordinates', 'Tìm tọa độ'),
      fields: const [
        FieldSpec(
          'latitude',
          'Latitude',
          'Vĩ độ',
          kind: FieldKind.number,
          min: -90,
          max: 90,
        ),
        FieldSpec(
          'longitude',
          'Longitude',
          'Kinh độ',
          kind: FieldKind.number,
          min: -180,
          max: 180,
        ),
      ],
    );
    if (body != null && mounted) {
      map.move(
        LatLng(
          (body['latitude'] as num).toDouble(),
          (body['longitude'] as num).toDouble(),
        ),
        17,
      );
    }
  }

  void confirm() {
    try {
      final ring = boundary, polygon = polygonPayload(ring);
      final chosen = center != null && shape == 'CIRCLE'
          ? center!
          : LatLng(
              (ring.map((p) => p.latitude).reduce(math.min) +
                      ring.map((p) => p.latitude).reduce(math.max)) /
                  2,
              (ring.map((p) => p.longitude).reduce(math.min) +
                      ring.map((p) => p.longitude).reduce(math.max)) /
                  2,
            );
      final coveringRadius = ring
          .map((p) => distanceMeters(chosen, p))
          .reduce(math.max);
      Navigator.pop(context, {
        'coverageArea': polygon,
        if (place case final String label when label.trim().isNotEmpty)
          'normalizedAddress': label,
        'latitude': chosen.latitude,
        'longitude': chosen.longitude,
        'radiusM': shape == 'CIRCLE' ? radius : coveringRadius,
        'coverageAreaShape': shape,
        'coverageAreaCenter': [chosen.longitude, chosen.latitude],
        'areaHa': coverageAreaM2(ring) / 10000,
        if (length != null) 'estimatedLengthM': length,
        if (attachments.isNotEmpty) 'areaFiles': attachments,
      });
    } catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Monitoring area', 'Khu vực giám sát')),
      actions: [
        IconButton(
          onPressed: coordinates,
          icon: const Icon(Icons.my_location),
          tooltip: context.tr('Coordinates', 'Tọa độ'),
        ),
        IconButton(
          onPressed: importArea,
          icon: const Icon(Icons.upload_file_outlined),
          tooltip: 'KML / GeoJSON',
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: address,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              hintText: context.tr('Search address', 'Tìm địa chỉ'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: busy ? null : search,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 'POLYGON',
                label: Text(context.tr('Polygon', 'Đa giác')),
              ),
              ButtonSegment(
                value: 'RECTANGLE',
                label: Text(context.tr('Rectangle', 'Chữ nhật')),
              ),
              ButtonSegment(
                value: 'CIRCLE',
                label: Text(context.tr('Circle', 'Hình tròn')),
              ),
            ],
            selected: {shape},
            onSelectionChanged: (value) => setState(() {
              shape = value.first;
              points.clear();
              center = null;
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            place ??
                (shape == 'CIRCLE'
                    ? context.tr(
                        'Tap to choose the centre.',
                        'Chạm để chọn tâm.',
                      )
                    : shape == 'RECTANGLE'
                    ? context.tr(
                        'Tap two opposite corners.',
                        'Chạm hai góc đối diện.',
                      )
                    : context.tr(
                        'Tap boundary points in order.',
                        'Chạm lần lượt các điểm ranh giới.',
                      )),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: FlutterMap(
            mapController: map,
            options: MapOptions(
              initialCenter: const LatLng(16.05, 108.2),
              initialZoom: 5,
              onTap: (_, point) => tap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'vn.odms.odms_mobile',
              ),
              if (boundary.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: boundary,
                      color: const Color(0x331565E8),
                      borderColor: const Color(0xFF1565E8),
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (final (i, point)
                      in (shape == 'CIRCLE'
                              ? center == null
                                    ? <LatLng>[]
                                    : [center!]
                              : points)
                          .indexed)
                    Marker(
                      point: point,
                      width: 24,
                      height: 24,
                      child: CircleAvatar(
                        backgroundColor: const Color(0xFF1565E8),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        if (shape == 'CIRCLE')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('${radius.round()} m'),
                Expanded(
                  child: Slider(
                    value: radius,
                    min: 100,
                    max: 1500,
                    divisions: 28,
                    label: '${radius.round()} m',
                    onChanged: (value) => setState(() => radius = value),
                  ),
                ),
              ],
            ),
          ),
        if (boundary.length >= 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.tr(
                'Area: ${(coverageAreaM2(boundary) / 10000).toStringAsFixed(2)} ha',
                'Diện tích: ${(coverageAreaM2(boundary) / 10000).toStringAsFixed(2)} ha',
              ),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        if (attachments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              attachments.map((e) => e['fileName']).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: points.isEmpty && center == null
                      ? null
                      : () => setState(() {
                          if (points.isNotEmpty) {
                            points.removeLast();
                          } else {
                            center = null;
                          }
                        }),
                  icon: const Icon(Icons.undo),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    points.clear();
                    center = null;
                    attachments.clear();
                    length = null;
                  }),
                  child: Text(context.tr('Clear', 'Xóa')),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: boundary.length >= 3 ? confirm : null,
                  child: Text(context.tr('Confirm area', 'Xác nhận khu vực')),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
