import 'package:flutter/material.dart';

import 'design/glass.dart';

/// Builds the app theme for one glass tone.
///
/// Material's own palette is deliberately kept thin: almost everything visible
/// is drawn by the widgets in `design/glass.dart`, and what is left (dialogs,
/// snack bars, text selection, progress rings) is mapped onto the same ramp so
/// a stray Material surface cannot punch a flat hole in the glass.
ThemeData buildTheme(GlassTone tone) {
  final ramp = GlassRamps.of(tone);
  final base = tone == GlassTone.dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    colorScheme: base.colorScheme.copyWith(
      primary: ramp.accent,
      secondary: ramp.accentDeep,
      surface: ramp.page,
      error: const Color(0xFFE5484D),
      onPrimary: Colors.white,
      onSurface: ramp.content,
      outline: ramp.hairline,
    ),
    dividerColor: ramp.hairline,
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme.apply(
      bodyColor: ramp.content,
      displayColor: ramp.content,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Color.alphaBlend(
        ramp.surface.withValues(alpha: 0.92),
        ramp.page,
      ),
      contentTextStyle: GlassText.body.copyWith(color: ramp.content),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GlassRadius.chip),
        side: BorderSide(color: ramp.hairline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Color.alphaBlend(
        ramp.surface.withValues(alpha: ramp.chromeTint + 0.2),
        ramp.page,
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GlassRadius.dialog),
        side: BorderSide(color: ramp.hairline),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: ramp.accent),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: ramp.accent,
      selectionColor: ramp.accent.withValues(alpha: 0.28),
      selectionHandleColor: ramp.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ramp.content.withValues(alpha: 0.05),
      hintStyle: GlassText.body.copyWith(color: ramp.contentFaint),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GlassRadius.pill),
        borderSide: BorderSide(color: ramp.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GlassRadius.pill),
        borderSide: BorderSide(color: ramp.accent, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GlassRadius.pill),
        borderSide: BorderSide(color: ramp.hairline),
      ),
    ),
  );
}
