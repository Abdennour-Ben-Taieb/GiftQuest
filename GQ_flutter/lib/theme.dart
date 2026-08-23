import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Sunset Pop" design tokens. This is the single source of truth for
/// color/typography — screens should read from [Theme.of(context)]
/// (colorScheme, textTheme, stickerTheme) rather than hardcoding hex values.
class AppColors {
  AppColors._();

  static const surface = Color(0xFF1C1B1F);
  static const primary = Color(0xFF4F378B);
  static const secondary = Color(0xFFD0BCFF);
}

/// Sticker-shadow styling shared by [StickerButton] and [StickerCard]: a
/// thick flat border plus a hard-edged (non-blurred) offset drop shadow, so
/// components read as a sticker peeling slightly off the surface.
@immutable
class StickerTheme extends ThemeExtension<StickerTheme> {
  const StickerTheme({
    required this.borderColor,
    required this.borderWidth,
    required this.shadowColor,
    required this.shadowOffset,
    required this.radius,
  });

  final Color borderColor;
  final double borderWidth;
  final Color shadowColor;
  final Offset shadowOffset;
  final double radius;

  static const defaults = StickerTheme(
    borderColor: Color(0xFF1C1B1F),
    borderWidth: 2.5,
    shadowColor: Color(0xFF1C1B1F),
    shadowOffset: Offset(4, 4),
    radius: 20,
  );

  @override
  StickerTheme copyWith({
    Color? borderColor,
    double? borderWidth,
    Color? shadowColor,
    Offset? shadowOffset,
    double? radius,
  }) {
    return StickerTheme(
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      radius: radius ?? this.radius,
    );
  }

  @override
  StickerTheme lerp(ThemeExtension<StickerTheme>? other, double t) {
    if (other is! StickerTheme) return this;
    return StickerTheme(
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      borderWidth: t < 0.5 ? borderWidth : other.borderWidth,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      shadowOffset: Offset.lerp(shadowOffset, other.shadowOffset, t)!,
      radius: t < 0.5 ? radius : other.radius,
    );
  }
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF6B4FB0),
    onPrimaryContainer: Color(0xFFEADDFF),
    secondary: AppColors.secondary,
    onSecondary: Color(0xFF381E72),
    secondaryContainer: Color(0xFF4F378B),
    onSecondaryContainer: Color(0xFFEADDFF),
    tertiary: Color(0xFFEFB8C8),
    onTertiary: Color(0xFF492532),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    surface: AppColors.surface,
    onSurface: Color(0xFFE6E1E5),
    surfaceContainerLowest: Color(0xFF120F14),
    surfaceContainerLow: Color(0xFF201F24),
    surfaceContainer: Color(0xFF262429),
    surfaceContainerHigh: Color(0xFF302E34),
    surfaceContainerHighest: Color(0xFF3B383F),
    onSurfaceVariant: Color(0xFFCAC4CF),
    outline: Color(0xFF948F99),
    outlineVariant: Color(0xFF49454E),
    inverseSurface: Color(0xFFE6E1E5),
    onInverseSurface: Color(0xFF1C1B1F),
    inversePrimary: Color(0xFF6B4FB0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  final baseText = ThemeData(brightness: Brightness.dark).textTheme;
  final bodyText = GoogleFonts.schibstedGroteskTextTheme(baseText);
  final headingText = GoogleFonts.fredokaTextTheme(baseText);

  final textTheme = bodyText.copyWith(
    displayLarge: headingText.displayLarge?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    displayMedium: headingText.displayMedium?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    displaySmall: headingText.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: headingText.headlineLarge?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: headingText.headlineMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    headlineSmall: headingText.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    titleLarge: headingText.titleLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  final pillBorderRadius = BorderRadius.circular(28);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,
    extensions: const [StickerTheme.defaults],
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      titleTextStyle: headingText.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: pillBorderRadius,
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: pillBorderRadius,
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: pillBorderRadius,
        borderSide: BorderSide(color: colorScheme.secondary, width: 1.5),
      ),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: colorScheme.secondary),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
  );
}
