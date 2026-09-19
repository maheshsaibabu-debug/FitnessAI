import 'package:flutter/material.dart';

/// A category color: a saturated foreground (icon) paired with its soft
/// pastel background — the "colored circle behind an icon" pattern used
/// throughout the app for goals, plan items, and achievements.
class CategoryColor {
  const CategoryColor(this.foreground, this.background);
  final Color foreground;
  final Color background;
}

/// Warm, rounded, illustration-friendly theme. Light mode is hand-tuned
/// (not purely seed-generated) to get the specific cream/off-white
/// warmth; dark mode falls back to a seeded scheme since it isn't the
/// primary design target yet.
class AppTheme {
  AppTheme._();

  static const Color _brandGreen = Color(0xFF2FAE66);

  /// A small fixed rotation of category colors — goals, daily-plan items,
  /// and achievements all cycle through this same palette so the visual
  /// language stays consistent instead of every screen inventing its own
  /// colors.
  static const List<CategoryColor> categoryColors = [
    CategoryColor(Color(0xFF2FAE66), Color(0xFFE3F5EC)), // green
    CategoryColor(Color(0xFFF79009), Color(0xFFFEF0E1)), // orange
    CategoryColor(Color(0xFF8B5CF6), Color(0xFFF1EBFC)), // purple
    CategoryColor(Color(0xFF3B82F6), Color(0xFFE8F0FE)), // blue
    CategoryColor(Color(0xFFEC4899), Color(0xFFFDEAF3)), // pink
    CategoryColor(Color(0xFF14B8A6), Color(0xFFE1F7F4)), // teal
  ];

  static CategoryColor categoryColorFor(String key) =>
      categoryColors[key.hashCode.abs() % categoryColors.length];

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: _brandGreen,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE3F5EC),
      onPrimaryContainer: Color(0xFF0B3D22),
      secondary: Color(0xFFF79009),
      surface: Color(0xFFFAF6EF),
      onSurface: Color(0xFF2A2A26),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFCFAF6),
      surfaceContainer: Color(0xFFFFFFFF),
      surfaceContainerHigh: Color(0xFFF3EEE4),
      surfaceContainerHighest: Color(0xFFF1ECE1),
      onSurfaceVariant: Color(0xFF6B6A63),
      outline: Color(0xFFD9D3C4),
      outlineVariant: Color(0xFFE7E2D5),
      error: Color(0xFFDC2626),
    );
    return _themeFrom(colorScheme);
  }

  static ThemeData dark() => _themeFrom(ColorScheme.fromSeed(seedColor: _brandGreen, brightness: Brightness.dark));

  static ThemeData _themeFrom(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: const TextTheme().apply(fontFamily: null),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: colorScheme.outline),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide.none,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
        height: 72,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 1),
    );
  }
}
