import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../shared/coverage_geometry.dart';
import '../../shared/strings.dart';

class OrderCoverageMap extends StatefulWidget {
  const OrderCoverageMap({super.key, required this.order});
  final Json order;
  @override
  State<OrderCoverageMap> createState() => _OrderCoverageMapState();
}

class _OrderCoverageMapState extends State<OrderCoverageMap> {
  bool satellite = false;
  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final lat = num.tryParse('${order['latitude']}')?.toDouble();
    final lon = num.tryParse('${order['longitude']}')?.toDouble();
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      return const SizedBox.shrink();
    }
    final center = LatLng(lat, lon);
    final geometry = object(order['coverageArea']);
    final rings = geometry['coordinates'];
    final points = <LatLng>[
      if (geometry['type'] == 'Polygon' &&
          rings is List &&
          rings.isNotEmpty &&
          rings.first is List)
        for (final pair in rings.first as List)
          if (pair is List &&
              pair.length >= 2 &&
              pair[0] is num &&
              pair[1] is num)
            LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
    ];
    final radius = num.tryParse('${order['radiusM']}')?.toDouble();
    final boundary = points.length >= 3 && validCoverage(points)
        ? points
        : radius != null && radius.isFinite && radius > 0
        ? circleBoundary(center, radius)
        : <LatLng>[];
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Monitoring area', 'Vùng giám sát'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => satellite = !satellite),
                icon: const Icon(Icons.layers_outlined),
                label: Text(
                  satellite
                      ? context.tr('Street', 'Đường phố')
                      : context.tr('Satellite', 'Vệ tinh'),
                ),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 216,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  initialCameraFit: boundary.isEmpty
                      ? null
                      : CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(boundary),
                          padding: const EdgeInsets.all(24),
                          maxZoom: 16,
                        ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: satellite
                        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    fallbackUrl: satellite ? null : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'vn.odms.odms_mobile',
                  ),
                  if (boundary.isNotEmpty)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: boundary,
                          color: color.withValues(alpha: .18),
                          borderColor: color,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 26,
                        height: 26,
                        child: Icon(Icons.location_on, color: color),
                      ),
                    ],
                  ),
                  SimpleAttributionWidget(
                    source: Text(
                      satellite
                          ? 'Esri'
                          : '© OpenStreetMap contributors · Esri',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
