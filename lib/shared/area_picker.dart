import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/models.dart';
import 'strings.dart';

Json polygonPayload(List<LatLng> points) {
  if (points.length < 3) {
    throw const FormatException('Select at least three boundary points.');
  }
  double signedArea = 0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i], b = points[(i + 1) % points.length];
    signedArea += a.longitude * b.latitude - b.longitude * a.latitude;
  }
  if (signedArea.abs() < 1e-12) {
    throw const FormatException('The selected area is empty.');
  }
  final ring = [...points, points.first];
  return {
    'type': 'Polygon',
    'coordinates': [
      ring.map((p) => [p.longitude, p.latitude]).toList(),
    ],
  };
}

class AreaPicker extends StatefulWidget {
  const AreaPicker({super.key});
  @override
  State<AreaPicker> createState() => _AreaPickerState();
}

class _AreaPickerState extends State<AreaPicker> {
  final points = <LatLng>[];
  final latitude = TextEditingController(), longitude = TextEditingController();
  final map = MapController();
  @override
  void dispose() {
    latitude.dispose();
    longitude.dispose();
    map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Monitoring area', 'Khu vực giám sát')),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.tr(
              'Tap the boundary points in order. Drag the map to your site.',
              'Chạm lần lượt các điểm ranh giới. Kéo bản đồ đến địa điểm của bạn.',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: latitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('Latitude', 'Vĩ độ'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: longitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('Longitude', 'Kinh độ'),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  final lat = double.tryParse(latitude.text),
                      lon = double.tryParse(longitude.text);
                  if (lat != null &&
                      lon != null &&
                      lat.abs() <= 90 &&
                      lon.abs() <= 180) {
                    map.move(LatLng(lat, lon), 17);
                  }
                },
                icon: const Icon(Icons.search),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FlutterMap(
            mapController: map,
            options: MapOptions(
              initialCenter: const LatLng(16.05, 108.2),
              initialZoom: 5,
              onTap: (_, point) => setState(() => points.add(point)),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'vn.odms.odms_mobile',
              ),
              if (points.length >= 3)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: points,
                      color: const Color(0x33176B52),
                      borderColor: const Color(0xFF176B52),
                      borderStrokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < points.length; i++)
                    Marker(
                      point: points[i],
                      width: 32,
                      height: 32,
                      child: CircleAvatar(child: Text('${i + 1}')),
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
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton(
                  onPressed: points.isEmpty
                      ? null
                      : () => setState(() => points.removeLast()),
                  child: Text(context.tr('Undo', 'Hoàn tác')),
                ),
                TextButton(
                  onPressed: () => setState(points.clear),
                  child: Text(context.tr('Clear', 'Xóa')),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: points.length < 3
                      ? null
                      : () {
                          try {
                            final polygon = polygonPayload(points);
                            Navigator.pop(context, {
                              'coverageArea': polygon,
                              'latitude':
                                  points
                                      .map((p) => p.latitude)
                                      .reduce((a, b) => a + b) /
                                  points.length,
                              'longitude':
                                  points
                                      .map((p) => p.longitude)
                                      .reduce((a, b) => a + b) /
                                  points.length,
                            });
                          } on FormatException catch (failure) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(failure.message)),
                            );
                          }
                        },
                  child: Text(context.tr('Use area', 'Chọn khu vực')),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
