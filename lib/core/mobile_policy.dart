import 'models.dart';

bool mayOpenMobilePath(AppRole role, String path) {
  if (['/home', '/profile', '/support', '/notifications'].contains(path)) {
    return true;
  }
  if (!path.startsWith('/${role.name}/')) {
    return false;
  }
  if (role != AppRole.staff) return true;
  final tail = path.substring('/staff/'.length).split('/');
  if (tail.length == 1) {
    return [
      'missions',
      'availability',
      'devices',
      'maintenance',
      'licenses',
      'zones',
    ].contains(tail.first);
  }
  return tail.first == 'missions' &&
      tail[1].isNotEmpty &&
      (tail.length == 2 ||
          tail.length == 3 && ['checklist', 'media'].contains(tail[2]));
}
