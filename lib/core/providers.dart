import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'config.dart';

final apiProvider = Provider<ApiClient>((ref) {
  final api = ApiClient(AppConfig.apiBaseUrl, SecureSecretStore());
  ref.onDispose(() => api.dio.close());
  return api;
});
