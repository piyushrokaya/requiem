import 'package:flutter/material.dart';

const _seedColor = Color(0xFF2F5DE3);

ThemeData buildAppTheme({bool highContrast = false, bool dyslexiaFriendly = false}) =>
    _buildTheme(
      Brightness.light,
      highContrast: highContrast,
      dyslexiaFriendly: dyslexiaFriendly,
    );

ThemeData buildAppDarkTheme({
  bool highContrast = false,
  bool dyslexiaFriendly = false,
}) => _buildTheme(
  Brightness.dark,
  highContrast: highContrast,
  dyslexiaFriendly: dyslexiaFriendly,
);

ThemeData _buildTheme(
  Brightness brightness, {
  required bool highContrast,
  required bool dyslexiaFriendly,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
    // Material 3 contrast dial: 0 is standard, 1 is maximum contrast.
    contrastLevel: highContrast ? 1.0 : 0.0,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final isDark = brightness == Brightness.dark;

  // Dyslexia-friendly readers benefit from extra letter/word spacing and
  // looser line height more than from a specific typeface, so we adjust
  // spacing/weight rather than bundling a custom font.
  final letterSpacing = dyslexiaFriendly ? 0.6 : null;
  final bodyHeight = dyslexiaFriendly ? 1.7 : 1.4;
  final bodyLargeHeight = dyslexiaFriendly ? 1.8 : 1.5;

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacing,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: letterSpacing,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        height: bodyHeight,
        letterSpacing: letterSpacing,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        height: bodyLargeHeight,
        letterSpacing: letterSpacing,
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 2,
      surfaceTintColor: scheme.surfaceTint,
      backgroundColor: scheme.surface,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      titleTextStyle: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
      side: BorderSide.none,
      labelStyle: base.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.5),
      space: 24,
      thickness: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.6 : 0.7,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 3,
      height: 68,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
    ),
  );
}
