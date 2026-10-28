// Design tokens transplanted from SleepDown-Schedule (Jetpack Compose / Miuix).
//
// The source project is a "liquid glass" course-table app: a cool grey page,
// heavily blurred translucent panels, pill-shaped chrome, and continuous
// (superellipse) corners instead of circular ones. This file is the Flutter
// translation of its token layer — values are kept numerically identical to
// the Compose originals wherever the concept maps 1:1, so the two apps read as
// the same family.
//
// Everything here is pure data: no widgets, no BuildContext.

import 'package:flutter/material.dart';

/// Surface "temperature". SleepDown flips its whole glass material on this:
/// a light wall paper yields white glass with black content, a dark one yields
/// near-black glass with white content.
enum GlassTone { light, dark }

/// Colour ramp for one tone. Two ramps exist (light / dark) and every widget
/// resolves the active one through [GlassPalette.of].
@immutable
class GlassRamp {
  const GlassRamp({
    required this.page,
    required this.pageVeil,
    required this.surface,
    required this.surfaceTop,
    required this.chromeTint,
    required this.panelTint,
    required this.content,
    required this.contentMuted,
    required this.contentFaint,
    required this.hairline,
    required this.accent,
    required this.accentDeep,
    required this.highlight,
    required this.shadow,
    required this.outerShadow,
    required this.innerShadow,
  });

  /// Page backdrop behind every panel.
  final Color page;

  /// Soft wash painted over [page] so the blur has something to chew on.
  final List<Color> pageVeil;

  /// Base colour mixed into the glass body.
  final Color surface;
  final Color surfaceTop;

  /// Alpha applied to [surface] for chrome (headers / dock) vs content panels.
  final double chromeTint;
  final double panelTint;

  final Color content;
  final Color contentMuted;
  final Color contentFaint;

  /// 1px border that reads as a cut glass edge.
  final Color hairline;

  final Color accent;
  final Color accentDeep;

  /// Top-edge lens: a 1px highlight that sells the "glass" read.
  final Color highlight;

  final List<BoxShadow> shadow;
  final List<BoxShadow> outerShadow;
  final List<BoxShadow> innerShadow;
}

/// SleepDown's accepted production values, one ramp per tone.
class GlassRamps {
  const GlassRamps._();

  /// `HomeLightGlassSurfaceColor` / `LightPageBackground` from the source.
  static const light = GlassRamp(
    page: Color(0xFFE4E5EB),
    pageVeil: [
      Color(0xFFEDEFF5),
      Color(0xFFDDE3EE),
      Color(0xFFE8E4EC),
    ],
    surface: Color(0xFFF2F4F8),
    surfaceTop: Color(0xFFF7F8FB),
    chromeTint: 0.54,
    panelTint: 0.42,
    content: Color(0xFF0B0C0E),
    contentMuted: Color(0xFF5C6270),
    contentFaint: Color(0xFF8A90A0),
    hairline: Color(0x1F0B0C0E),
    accent: Color(0xFF0A84FF),
    accentDeep: Color(0xFF006FD6),
    highlight: Color(0x2EFFFFFF),
    shadow: [
      BoxShadow(color: Color(0x0D000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
    outerShadow: [
      BoxShadow(color: Color(0x05000000), blurRadius: 40, offset: Offset(0, 18)),
    ],
    innerShadow: [
      BoxShadow(color: Color(0x14000000), blurRadius: 2, spreadRadius: -1),
    ],
  );

  /// `CenteredDialog.DarkSurfaceAlpha` = 0.74 on a near-black base.
  static const dark = GlassRamp(
    page: Color(0xFF07080A),
    pageVeil: [
      Color(0xFF121722),
      Color(0xFF0A0D13),
      Color(0xFF141018),
    ],
    surface: Color(0xFF050505),
    surfaceTop: Color(0xFF14161B),
    chromeTint: 0.62,
    panelTint: 0.48,
    content: Color(0xFFF4F6FA),
    contentMuted: Color(0xFF9AA2B2),
    contentFaint: Color(0xFF646C7C),
    hairline: Color(0x1FFFFFFF),
    accent: Color(0xFF4DA3FF),
    accentDeep: Color(0xFF2B7FD4),
    highlight: Color(0x1FFFFFFF),
    shadow: [
      BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 10)),
    ],
    outerShadow: [
      BoxShadow(color: Color(0x4D000000), blurRadius: 44, offset: Offset(0, 20)),
    ],
    innerShadow: [
      BoxShadow(color: Color(0x33FFFFFF), blurRadius: 2, spreadRadius: -1),
    ],
  );

  static GlassRamp of(GlassTone tone) =>
      tone == GlassTone.light ? light : dark;
}

/// Geometry. Mirrors `SleepDownDesignTokens` so radii stay in the same rhythm:
/// chrome pills are fully round, content panels sit at 24, dialogs at 32.
class GlassRadius {
  const GlassRadius._();

  /// Fully round: buttons, chips, single-line fields, the dock.
  static const pill = 999.0;

  /// Inner content panels (`QuickSheet.InnerCorner`).
  static const inner = 24.0;

  /// Standard content panel — the workhorse radius.
  static const panel = 26.0;

  /// Bottom sheets (`QuickSheet.BottomCorner`).
  static const sheet = 28.0;

  /// Dialogs (`Dialog.ContainerCorner`).
  static const dialog = 32.0;

  /// Compact alert shell (`CenteredDialog.Corner`).
  static const alert = 39.0;

  /// Small inline chips inside a panel.
  static const chip = 16.0;
}

/// Spacing rhythm — SleepDown keeps a tight 2dp grid for dense pages.
class GlassGap {
  const GlassGap._();

  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 26.0;
  static const xxl = 34.0;

  /// `SecondaryPage.HorizontalPadding`.
  static const pageH = 16.0;

  /// Clears the floating dock.
  static const dockInset = 116.0;

  /// `SecondaryPage.CompactTopBarHeight`.
  static const topBar = 58.0;
}

/// Blur sigmas. Compose uses dp; Flutter's `ImageFilter.blur` wants sigma, and
/// sigma ≈ dp reads close enough at 1x that the two look alike.
class GlassBlur {
  const GlassBlur._();

  /// `CenteredDialog.BackgroundBlur`.
  static const dialog = 10.0;

  /// `CenteredDialog.MaxBlur`.
  static const max = 16.0;

  /// Chrome (headers, dock) sits lighter so text stays crisp.
  static const chrome = 14.0;

  /// Content panels.
  static const panel = 18.0;

  /// The page wash behind everything — barely there, just enough depth.
  static const veil = 60.0;
}

/// Typography. SleepDown leans on size + weight contrast rather than colour:
/// a heavy display line, a mid-weight label, and a small grey caption.
class GlassText {
  const GlassText._();

  static const display = TextStyle(
    fontSize: 30,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
  );

  static const title = TextStyle(
    fontSize: 17,
    height: 1.24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const body = TextStyle(
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const label = TextStyle(
    fontSize: 12.5,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const caption = TextStyle(
    fontSize: 11.5,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  /// Metrics use tabular-ish monospace so digits do not jitter while polling.
  static const metric = TextStyle(
    fontSize: 25,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const mono = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
    fontFamily: 'monospace',
  );
}

/// Semantic colours. SleepDown keeps its status hues outside the tone ramps so
/// "failed" reads the same red in light and dark; these are tuned to sit on the
/// glass without vibrating against it.
class GlassStatus {
  const GlassStatus._();

  static const ok = Color(0xFF2FB683);
  static const warn = Color(0xFFE0A93B);
  static const danger = Color(0xFFE5484D);
  static const info = Color(0xFF5B8DEF);
  static const neutral = Color(0xFF8A90A0);
}

/// Motion. SleepDown's glass transitions are slow-ish and springy; these are
/// the durations that reproduce that feel without a physics simulation.
class GlassMotion {
  const GlassMotion._();

  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);

  static const curve = Curves.easeOutCubic;
  static const springy = Curves.easeOutBack;
}
