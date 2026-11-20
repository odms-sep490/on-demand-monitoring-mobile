import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const cognitoDomain = String.fromEnvironment('COGNITO_DOMAIN');
  static const cognitoClientId = String.fromEnvironment('COGNITO_CLIENT_ID');
  static const oauthRedirect = String.fromEnvironment('OAUTH_REDIRECT_URI');

  static String? validate() {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !['http', 'https'].contains(uri.scheme)) {
      return 'Set API_BASE_URL to your ODMS server URL.';
    }
    if (kReleaseMode && uri.scheme != 'https') {
      return 'Release builds require HTTPS.';
    }
    return null;
  }
}
