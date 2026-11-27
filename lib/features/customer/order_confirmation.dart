import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../shared/mobile_ui.dart';
import '../../shared/portal_scaffold.dart';
import '../../shared/strings.dart';
import '../../shared/widgets.dart';
import 'site_advisory_data.dart';
import 'weather_summary.dart';

class SiteAdvisoryPage extends ConsumerWidget {
  const SiteAdvisoryPage({
    super.key,
    required this.order,
    this.area = const {},
    this.confirm = false,
  });
  final Json order, area;
  final bool confirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PortalScaffold(
    appBar: AppBar(
      title: Text(
        confirm
            ? context.tr('Review your request', 'Kiểm tra yêu cầu')
            : context.tr('Site and weather', 'Địa điểm và thời tiết'),
      ),
    ),
    body: RemoteView(
      load: () => loadSiteAdvisory(
        ref.read(apiProvider),
        order: order,
        area: area,
        confirm: confirm,
      ),
      builder: (context, value, reload) {
        final data = object(value),
            risk = object(object(value)['risk']),
            weather = object(object(value)['weather']),
            quote = object(object(value)['quote']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (confirm)
              SectionCard(
                title: context.tr('Request summary', 'Tóm tắt yêu cầu'),
                child: DetailFields(
                  data: order,
                  fields: const {
                    'title': ('Title', 'Tiêu đề'),
                    'description': ('Description', 'Mô tả'),
                    'address': ('Site', 'Địa điểm'),
                    'preferredDateFrom': ('From', 'Từ ngày'),
                    'preferredDateTo': ('To', 'Đến ngày'),
                    'altitudeM': ('Altitude (m)', 'Độ cao (m)'),
                    'siteContactName': ('Site contact', 'Người liên hệ'),
                    'siteContactPhone': ('Phone', 'Điện thoại'),
                    'permitStatus': ('Permit', 'Giấy phép'),
                    'resultFormats': ('Result formats', 'Định dạng kết quả'),
                    'dataRetentionDays': ('Retention (days)', 'Lưu trữ (ngày)'),
                  },
                ),
              ),
            SectionCard(
              title: context.tr('Weather forecast', 'Dự báo thời tiết'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data['weatherError'] != null)
                    Text('${data['weatherError']}'),
                  if (weather['status'] == 'FORECAST_NOT_AVAILABLE')
                    Text(
                      context.tr(
                        'The forecast is not available for this date yet.',
                        'Chưa có dự báo cho ngày đã chọn.',
                      ),
                    ),
                  if (weather['status'] == 'AVAILABLE')
                    WeatherSummary(weather: weather),
                  DetailFields(
                    data: weather,
                    fields: const {
                      'weatherLabel': ('Conditions', 'Điều kiện'),
                      'forecastTime': ('Forecast time', 'Thời gian dự báo'),
                      'relativeHumidityPercent': ('Humidity (%)', 'Độ ẩm (%)'),
                      'precipitationMm': (
                        'Precipitation (mm)',
                        'Lượng mưa (mm)',
                      ),
                      'cloudCoverPercent': (
                        'Cloud cover (%)',
                        'Mây che phủ (%)',
                      ),
                      'windGustKmh': ('Gust (km/h)', 'Gió giật (km/h)'),
                      'visibilityMeters': ('Visibility (m)', 'Tầm nhìn (m)'),
                      'suitability': ('Suitability', 'Mức độ phù hợp'),
                      'warnings': ('Warnings', 'Lưu ý'),
                    },
                  ),
                  Text(
                    context.tr(
                      'Advisory only. Actual operating conditions are checked by staff.',
                      'Thông tin tham khảo. Nhân viên xác nhận điều kiện thực tế khi thực hiện.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SectionCard(
              title: context.tr('Area assessment', 'Đánh giá khu vực'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (data['riskError'] != null)
                    Text(
                      data['riskError'] == 'LOCATION_INCOMPLETE'
                          ? context.tr(
                              'The order has no complete confirmed area for an assessment.',
                              'Đơn chưa có đủ thông tin khu vực để đánh giá.',
                            )
                          : '${data['riskError']}',
                    ),
                  DetailFields(
                    data: object(risk['assessment']),
                    fields: const {
                      'level': ('Assessment', 'Mức đánh giá'),
                      'disclaimer': ('Note', 'Lưu ý'),
                    },
                  ),
                  for (final finding in records(
                    object(risk['assessment'])['findings'],
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('${finding['message']}'),
                    ),
                  DetailFields(
                    data: object(risk['elevation']),
                    fields: const {
                      'terrainElevationMeters': (
                        'Terrain elevation (m)',
                        'Cao độ địa hình (m)',
                      ),
                      'estimatedFlightAltitudeAmslMeters': (
                        'Estimated AMSL (m)',
                        'Độ cao so với mực nước biển (m)',
                      ),
                    },
                  ),
                  for (final zone in records(
                    object(risk['restrictedZones'])['affectedZones'],
                  ))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.info_outline),
                      title: Text('${zone['name']}'),
                      subtitle: Text(
                        '${zone['zoneType'] ?? ''} · ${zone['distanceMeters'] ?? '—'} m',
                      ),
                    ),
                  DetailFields(
                    data: object(risk['osmContext']),
                    fields: const {
                      'buildingCount': ('Buildings', 'Công trình'),
                      'towerCount': ('Towers', 'Tháp'),
                      'powerTowerCount': ('Power towers', 'Cột điện'),
                      'aerodromeNearby': ('Nearby aerodrome', 'Gần sân bay'),
                      'helipadNearby': ('Nearby helipad', 'Gần bãi đáp'),
                    },
                  ),
                ],
              ),
            ),
            if (confirm)
              SectionCard(
                title: context.tr('Estimated pricing', 'Giá dự kiến'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (data['quoteError'] != null)
                      Text('${data['quoteError']}'),
                    DetailFields(
                      data: quote,
                      fields: const {
                        'serviceName': ('Service', 'Dịch vụ'),
                        'total': (
                          'Estimated total (VND)',
                          'Tổng dự kiến (VND)',
                        ),
                        'occurrences': ('Visits', 'Số lượt'),
                        'warnings': ('Notes', 'Lưu ý'),
                      },
                    ),
                    for (final checklist in records(quote['checklists'])) ...[
                      Text(
                        '${checklist['content']}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      DetailFields(
                        data: checklist,
                        fields: const {
                          'calculationDisplay': ('Calculation', 'Cách tính'),
                          'subtotal': ('Subtotal (VND)', 'Tạm tính (VND)'),
                        },
                      ),
                      for (final line in records(checklist['lines']))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${line['description']}: ${line['amount']} VND',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                    for (final addOn in records(quote['addOns']))
                      Text('${addOn['description']}: ${addOn['amount']} VND'),
                    if (quote['quotePending'] == true ||
                        quote['complete'] == false)
                      Text(
                        context.tr(
                          'Some requirements need a manager quote. The final quote is approved separately.',
                          'Một số yêu cầu cần manager báo giá. Báo giá cuối cùng sẽ được duyệt riêng.',
                        ),
                      ),
                  ],
                ),
              ),
            TextButton(
              onPressed: reload,
              child: Text(context.tr('Refresh advisory', 'Cập nhật thông tin')),
            ),
            if (confirm)
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check),
                label: Text(context.tr('Submit request', 'Gửi yêu cầu')),
              ),
          ],
        );
      },
    ),
  );
}
