import 'package:flutter/material.dart';

/// App-wide `ThemeData`: OLED black scaffolding, mint accent, no ripples noise.
ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: QqaColors.bg,
    canvasColor: QqaColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: QqaColors.accent,
      secondary: QqaColors.accent,
      surface: QqaColors.surface,
      error: QqaColors.danger,
      onPrimary: QqaColors.bg,
      onSurface: QqaColors.text,
    ),
    dividerColor: QqaColors.line,
    splashFactory: InkSparkle.splashFactory,
    textTheme: base.textTheme.apply(
      bodyColor: QqaColors.text,
      displayColor: QqaColors.text,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: QqaColors.surfaceAlt,
      contentTextStyle: TextStyle(color: QqaColors.text, fontSize: 13),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: QqaColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: QqaColors.accent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: QqaColors.surfaceAlt,
      hintStyle: const TextStyle(color: QqaColors.faint, fontSize: 13.5),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: QqaColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: QqaColors.accent, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: QqaColors.line),
      ),
    ),
  );
}

/// Palette lifted from the target mock-up: OLED black, near-black cards,
/// a single mint accent, and cool grey supporting text.
class QqaColors {
  const QqaColors._();

  static const bg = Color(0xFF0A0A0C);
  static const surface = Color(0xFF121317);
  static const surfaceAlt = Color(0xFF171A1F);
  static const line = Color(0xFF22252C);
  static const text = Color(0xFFF2F4F8);
  static const muted = Color(0xFF8A93A6);
  static const faint = Color(0xFF5A6274);
  static const accent = Color(0xFF3DDC97);
  static const accentDeep = Color(0xFF1B7F5C);
  static const accentGlow = Color(0xFF2FBF83);
  static const danger = Color(0xFFFF7A72);
  static const warn = Color(0xFFF3C46B);
  static const info = Color(0xFF7FB2FF);

  /// Gradient used by the big hero card.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2FBF83), Color(0xFF15496B), Color(0xFF101C2C)],
    stops: [0.0, 0.55, 1.0],
  );
}

/// Typography: big numerals, small monospace key labels.
class QqaText {
  const QqaText._();

  static const mono = 'monospace';

  static const display = TextStyle(
    color: QqaColors.text,
    fontSize: 30,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const title = TextStyle(
    color: QqaColors.text,
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    color: QqaColors.text,
    fontSize: 14,
    height: 1.45,
  );

  static const muted = TextStyle(
    color: QqaColors.muted,
    fontSize: 12.5,
    height: 1.4,
  );

  static const key = TextStyle(
    color: QqaColors.faint,
    fontSize: 11,
    height: 1.3,
    fontFamily: mono,
  );

  static const metric = TextStyle(
    color: QqaColors.text,
    fontSize: 22,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );
}

/// Shared card / pill decorations so every screen looks the same.
class QqaDecor {
  const QqaDecor._();

  static BoxDecoration card({Color? color, double radius = 18}) => BoxDecoration(
        color: color ?? QqaColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: QqaColors.line),
      );

  static BoxDecoration pill({Color color = QqaColors.accent, double alpha = 0.14}) =>
      BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      );
}

/// One labelled number block used by the 2x2 grids.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.value,
    required this.label,
    this.hint,
    this.valueColor,
  });

  final String value;
  final String label;
  final String? hint;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: QqaText.metric.copyWith(color: valueColor ?? QqaText.metric.color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(label, style: QqaText.muted, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, style: QqaText.key, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }
}

/// Section heading: bold title on the left, optional action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(title, style: QqaText.title),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
