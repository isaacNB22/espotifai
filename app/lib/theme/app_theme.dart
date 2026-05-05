import 'package:flutter/material.dart';

// Colores Spotify
const _kGreen = Color(0xFF1DB954);
const _kBlack = Color(0xFF121212);
const _kSurface2 = Color(0xFF282828);
const _kSurface3 = Color(0xFF333333);
const _kWhite = Color(0xFFFFFFFF);
const _kGrey = Color(0xFFB3B3B3);

ThemeData darkTheme() {
  final cs = ColorScheme(
    brightness: Brightness.dark,
    primary: _kGreen,
    onPrimary: _kBlack,
    primaryContainer: _kSurface2,
    onPrimaryContainer: _kWhite,
    secondary: _kGreen,
    onSecondary: _kBlack,
    secondaryContainer: _kSurface3,
    onSecondaryContainer: _kWhite,
    tertiary: _kGreen,
    onTertiary: _kBlack,
    tertiaryContainer: _kSurface2,
    onTertiaryContainer: _kWhite,
    error: const Color(0xFFCF6679),
    onError: _kBlack,
    errorContainer: const Color(0xFF8B0000),
    onErrorContainer: _kWhite,
    surface: _kBlack,
    onSurface: _kWhite,
    surfaceContainerHighest: _kSurface2,
    onSurfaceVariant: _kGrey,
    outline: _kSurface3,
    shadow: Colors.black,
    inverseSurface: _kWhite,
    onInverseSurface: _kBlack,
    inversePrimary: _kGreen,
    surfaceTint: Colors.transparent,
  );

  return _buildTheme(cs);
}

ThemeData lightTheme() {
  const lBg = Color(0xFFF7F7F7);
  const lSurface2 = Color(0xFFEEEEEE);
  const lOnSurface = Color(0xFF121212);
  const lGrey = Color(0xFF6B6B6B);

  final cs = ColorScheme(
    brightness: Brightness.light,
    primary: _kGreen,
    onPrimary: _kWhite,
    primaryContainer: lSurface2,
    onPrimaryContainer: lOnSurface,
    secondary: const Color(0xFF158A3E),
    onSecondary: _kWhite,
    secondaryContainer: lSurface2,
    onSecondaryContainer: lOnSurface,
    tertiary: _kGreen,
    onTertiary: _kWhite,
    tertiaryContainer: lSurface2,
    onTertiaryContainer: lOnSurface,
    error: const Color(0xFFB00020),
    onError: _kWhite,
    errorContainer: const Color(0xFFFFDAD6),
    onErrorContainer: const Color(0xFF410002),
    surface: lBg,
    onSurface: lOnSurface,
    surfaceContainerHighest: Colors.white,
    onSurfaceVariant: lGrey,
    outline: lSurface2,
    shadow: Colors.black26,
    inverseSurface: lOnSurface,
    onInverseSurface: _kWhite,
    inversePrimary: _kGreen,
    surfaceTint: Colors.transparent,
  );

  return _buildTheme(cs);
}

ThemeData _buildTheme(ColorScheme cs) {
  final dark = cs.brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    fontFamily: 'CircularStd',
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: cs.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: cs.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 14, color: cs.onSurface),
      bodyMedium: TextStyle(fontSize: 13, color: cs.onSurface),
      bodySmall: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
    ),
    cardTheme: CardTheme(
      color: dark ? const Color(0xFF282828) : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: _kGreen, width: 2),
      ),
      hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _kGreen,
        foregroundColor: _kBlack,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onSurface,
        side: BorderSide(color: cs.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF0D0D0D) : Colors.white,
      indicatorColor: _kGreen.withValues(alpha: 0.15),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _kGreen, size: 24);
        }
        return IconThemeData(color: cs.onSurfaceVariant, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            color: _kGreen,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          );
        }
        return TextStyle(color: cs.onSurfaceVariant, fontSize: 11);
      }),
      elevation: 8,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: _kGreen,
      inactiveTrackColor:
          dark ? const Color(0xFF4D4D4D) : const Color(0xFFCCCCCC),
      thumbColor: _kWhite,
      overlayColor: _kGreen.withValues(alpha: 0.15),
      trackHeight: 3,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
    dividerTheme: DividerThemeData(
      color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
      thickness: 1,
    ),
    iconTheme: IconThemeData(color: cs.onSurface, size: 22),
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: cs.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      iconTheme: IconThemeData(color: cs.onSurface),
    ),
  );
}
