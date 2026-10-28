// Liquid-glass widget layer, transplanted from SleepDown-Schedule (Compose/Miuix).
//
// The look rests on four things, in order of importance:
//   1. a cool grey page with a soft colour wash, so there is something to blur;
//   2. translucent panels that actually blur what is behind them;
//   3. a 1px lens highlight on the top edge + a hairline border, which is what
//      makes the panel read as *glass* rather than as a flat grey box;
//   4. pill chrome and continuous-ish large radii instead of 12dp rounded rects.
//
// Everything is token-driven through [GlassScope]; a widget never hard-codes a
// colour, so flipping light/dark recolours the whole tree at once.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'liquid_glass.dart';
import 'tokens.dart';

export 'liquid_glass.dart';
export 'tokens.dart';

/// Provides the active [GlassRamp] to the subtree.
///
/// Screens read it with `GlassScope.of(context)`; the shell swaps the tone when
/// the user flips the theme switch, and every descendant rebuilds.
class GlassScope extends InheritedWidget {
  const GlassScope({super.key, required this.tone, required super.child});

  final GlassTone tone;

  GlassRamp get ramp => GlassRamps.of(tone);
  bool get isDark => tone == GlassTone.dark;

  static GlassScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GlassScope>();
    assert(scope != null, 'GlassScope missing above this widget');
    return scope!;
  }

  /// Convenience: the active ramp without holding on to the scope.
  static GlassRamp rampOf(BuildContext context) => of(context).ramp;

  @override
  bool updateShouldNotify(GlassScope oldWidget) => oldWidget.tone != tone;
}

/// Paints the page backdrop: a base colour plus three slow colour blobs.
///
/// Without this the blur has nothing interesting to sample and every panel
/// looks like flat grey paint, so this widget is load-bearing, not decoration.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: ramp.page)),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _VeilPainter(ramp)),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _VeilPainter extends CustomPainter {
  const _VeilPainter(this.ramp);

  final GlassRamp ramp;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        ramp.pageVeil,
        const [0.0, 0.55, 1.0],
      );
    canvas.drawRect(Offset.zero & size, base);

    // Three soft blooms. Positions are relative so the wash survives rotation.
    void bloom(double dx, double dy, double radius, Color color, double alpha) {
      final center = Offset(size.width * dx, size.height * dy);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          size.shortestSide * radius,
          [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        );
      canvas.drawCircle(center, size.shortestSide * radius, paint);
    }

    bloom(0.12, 0.06, 0.72, ramp.accent, 0.20);
    bloom(0.92, 0.28, 0.62, ramp.accentDeep, 0.16);
    bloom(0.62, 0.94, 0.78, ramp.accent, 0.12);
  }

  @override
  bool shouldRepaint(_VeilPainter oldDelegate) => oldDelegate.ramp != ramp;
}

/// A translucent, blurred panel — the single most-used surface in the app.
///
/// [GlassPanel] is for content; [GlassChrome] is the same material with a
/// stronger tint, used for headers and the dock so text on top stays legible.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = GlassRadius.panel,
    this.padding = const EdgeInsets.all(GlassGap.md),
    this.blur = GlassBlur.panel,
    this.tint,
    this.border = true,
    this.highlight = true,
    this.margin,
    this.onTap,
    this.clip = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;

  /// Overrides the ramp's `panelTint`. 0..1.
  final double? tint;
  final bool border;
  final bool highlight;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final alpha = tint ?? ramp.panelTint;

    // 真正的液态玻璃：折射 + 染色 + 高光 + 内阴影由片元着色器一次出图。
    // 参数取自 SleepDown 的 GlassMaterialSpec.dialog()，观感与上游同族。
    final material = GlassMaterial.dialog(intensity: 1).copyWith(
      blur: blur,
      surfaceAlpha: alpha,
      borderAlpha: border ? 0.24 : 0,
      highlightAlpha: highlight ? 0.06 : 0,
    );

    Widget body = LiquidGlass(
      material: material,
      radius: radius,
      padding: padding,
      shadow: border,
      child: child,
    );

    if (onTap != null) {
      body = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          splashColor: ramp.accent.withValues(alpha: 0.06),
          highlightColor: ramp.accent.withValues(alpha: 0.04),
          child: body,
        ),
      );
    }

    if (margin != null) {
      body = Padding(padding: margin!, child: body);
    }
    return body;
  }
}

/// Header / dock material: same glass, more tint, less blur bleed.
class GlassChrome extends StatelessWidget {
  const GlassChrome({
    super.key,
    required this.child,
    this.radius = GlassRadius.pill,
    this.padding = EdgeInsets.zero,
    this.blur = GlassBlur.chrome,
    this.margin,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    // 顶栏 / Dock 用 pill 材质再压一层染色：上游 chromeTint 0.54~0.62。
    final material = GlassMaterial.pill(intensity: 1.15).copyWith(
      blur: blur,
      surfaceAlpha: ramp.chromeTint * 0.55,
      borderAlpha: 0.30,
      highlightAlpha: 0.07,
      shadowAlpha: 0.16,
    );

    Widget body = LiquidGlass(
      material: material,
      radius: radius,
      padding: padding,
      child: child,
    );

    if (margin != null) body = Padding(padding: margin!, child: body);
    return body;
  }
}

/// Floating dock — SleepDown's replacement for a bottom nav bar.
///
/// Five destinations in a pill that hovers above the page edge; the selected
/// one gets a filled capsule that animates its width.
class GlassDock extends StatelessWidget {
  const GlassDock({
    super.key,
    required this.labels,
    required this.icons,
    required this.index,
    required this.onSelect,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return GlassChrome(
      radius: GlassRadius.pill,
      blur: GlassBlur.chrome,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            _DockItem(
              label: labels[i],
              icon: icons[i],
              selected: i == index,
              ramp: ramp,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.ramp,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final GlassRamp ramp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ramp.accent : ramp.contentMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: GlassMotion.base,
        curve: GlassMotion.curve,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 15 : 13,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected
              ? ramp.accent.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(GlassRadius.pill),
          border: Border.all(
            color: selected
                ? ramp.accent.withValues(alpha: 0.42)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: color),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GlassText.label.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Filled capsule button — the primary action everywhere.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.busy = false,
    this.tone = GlassButtonTone.accent,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;
  final GlassButtonTone tone;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final (fg, bg) = switch (tone) {
      GlassButtonTone.accent => (Colors.white, ramp.accent),
      GlassButtonTone.quiet => (ramp.content, ramp.content.withValues(alpha: 0.08)),
      GlassButtonTone.danger => (
          Colors.white,
          const Color(0xFFE5484D),
        ),
    };
    final enabled = onTap != null && !busy;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(GlassRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(GlassRadius.pill),
              border: Border.all(color: fg.withValues(alpha: 0.14)),
              boxShadow: tone == GlassButtonTone.accent
                  ? [
                      BoxShadow(
                        color: ramp.accent.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 17, color: fg),
                if (busy || icon != null) const SizedBox(width: 8),
                Text(
                  label,
                  style: GlassText.label.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum GlassButtonTone { accent, quiet, danger }

/// Translucent capsule with an optional status dot — tags, counts, states.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.text,
    this.icon,
    this.dotColor,
    this.color,
    this.dense = false,
  });

  final String text;
  final IconData? icon;

  /// When set, a small filled circle replaces [icon] (connection state).
  final Color? dotColor;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final tint = color ?? ramp.content;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 11,
        vertical: dense ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(GlassRadius.pill),
        border: Border.all(color: tint.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6.5,
              height: 6.5,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dotColor!.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 13, color: tint),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tint,
              fontSize: dense ? 11 : 12,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading with an optional trailing action, matching SleepDown's
/// `SecondaryPage` header rhythm.
class GlassSectionHeader extends StatelessWidget {
  const GlassSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, GlassGap.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: GlassText.title.copyWith(color: ramp.content)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      style: GlassText.caption
                          .copyWith(color: ramp.contentFaint)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Hairline divider that matches the glass edge colour.
class GlassDivider extends StatelessWidget {
  const GlassDivider({super.key, this.inset = 0});

  final double inset;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: 10),
      child: Container(height: 1, color: ramp.hairline),
    );
  }
}

/// Empty state: icon in a glass puck, a title, and one line of help.
class GlassEmpty extends StatelessWidget {
  const GlassEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: ramp.content.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: ramp.hairline),
              ),
              child: Icon(icon, size: 25, color: ramp.contentFaint),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: GlassText.body.copyWith(
                    color: ramp.contentMuted,
                    fontWeight: FontWeight.w600)),
            if (hint != null) ...[
              const SizedBox(height: 5),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: GlassText.caption.copyWith(color: ramp.contentFaint)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One labelled figure for the 2x2 metric grids.
class GlassMetric extends StatelessWidget {
  const GlassMetric({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;

  /// Optional tap target — used to cycle the token unit.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GlassText.caption.copyWith(color: ramp.contentFaint)),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GlassText.metric
              .copyWith(color: valueColor ?? ramp.content, fontSize: 25),
        ),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GlassText.mono.copyWith(color: ramp.contentFaint)),
        ],
      ],
    );
    if (onTap == null) return column;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: column,
    );
  }
}

/// Rounded bottom sheet in the same glass material.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final ramp = GlassScope.rampOf(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    builder: (sheetContext) => GlassScope(
      tone: GlassScope.of(context).tone,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: GlassPanel(
          radius: GlassRadius.sheet,
          blur: GlassBlur.dialog,
          tint: ramp.chromeTint,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: ramp.contentFaint.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(GlassRadius.pill),
                ),
              ),
              Flexible(child: builder(sheetContext)),
            ],
          ),
        ),
      ),
    ),
  );
}
