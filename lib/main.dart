import 'package:material_ui/material_ui.dart';

import 'app/theme.dart';

void main() => runApp(
  const MaterialApp(
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: [Locale('vi'), Locale('en')],
    home: FoundationScreen(),
  ),
);

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({super.key});
  @override
  Widget build(BuildContext context) => Theme(
    data: odmsTheme(),
    child: const Scaffold(body: Center(child: Text('ODMS Mobile'))),
  );
}
