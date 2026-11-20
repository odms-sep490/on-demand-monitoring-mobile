import 'package:material_ui/material_ui.dart';

ThemeData odmsTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565E8)),
  scaffoldBackgroundColor: const Color(0xFFF2F4F7),
  appBarTheme: const AppBarTheme(
    centerTitle: false,
    backgroundColor: Color(0xFFF2F4F7),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.all(16),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
);
