import 'api_client.dart';
import 'models.dart';

Future<Map<String, String>> lookup(
  ApiClient api,
  String path, {
  Json? query,
  String key = 'id',
  String label = 'name',
}) async => {
  for (final item in records(await api.request(path, query: query)))
    '${item[key]}': '${item[label] ?? recordTitle(item)}',
};
