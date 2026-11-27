import 'package:uuid/uuid.dart';

String newRequestId() => const Uuid().v4();

typedef Json = Map<String, dynamic>;

enum AppRole { customer, staff, manager }

AppRole parseRole(String value) => switch (value) {
  'CUSTOMER' => AppRole.customer,
  'STAFF' => AppRole.staff,
  _ => throw const FormatException(
    'This account role is not supported on mobile.',
  ),
};

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });
  final String id, email, fullName;
  final AppRole role;
  factory AppUser.fromJson(Json json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['fullName'] as String,
    role: parseRole(json['role'] as String),
  );
}

Json object(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Json> records(Object? value) {
  if (value is List) return value.map(object).toList();
  final json = object(value);
  return records(json['items'] ?? json['content'] ?? const <Object>[]);
}

String recordTitle(Json json) {
  for (final key in [
    'title',
    'subject',
    'scopeLabel',
    'name',
    'fileName',
    'reference',
    'missionCode',
    'orderCode',
    'ticketCode',
    'fullName',
    'code',
  ]) {
    if (json[key] is String && (json[key] as String).isNotEmpty) {
      return json[key] as String;
    }
  }
  return '${json['id'] ?? ''}';
}

String recordStatus(Json json) =>
    '${json['missionCode'] != null ? json['status'] ?? '' : json['orderStatus'] ?? json['status'] ?? json['type'] ?? ''}';

String segment(String id) => Uri.encodeComponent(id);
