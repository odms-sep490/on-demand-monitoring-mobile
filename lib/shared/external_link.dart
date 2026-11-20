import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';

Future<void> openExternal(Object? value) async {
  final uri = Uri.tryParse('$value');
  if (uri == null ||
      !uri.hasAuthority ||
      !['https', 'http'].contains(uri.scheme) ||
      uri.userInfo.isNotEmpty) {
    throw const ApiFailure('The server did not provide a valid link.');
  }
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw const ApiFailure('Unable to open this link.');
  }
}
