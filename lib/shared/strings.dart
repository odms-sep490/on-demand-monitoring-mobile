import 'package:material_ui/material_ui.dart';

class Strings {
  const Strings(this.locale);
  final Locale locale;
  String call(String en, String vi) => locale.languageCode == 'vi' ? vi : en;
  static Strings of(BuildContext context) =>
      Strings(Localizations.localeOf(context));
}

extension TranslatedContext on BuildContext {
  String tr(String en, String vi) => Strings.of(this)(en, vi);
}
