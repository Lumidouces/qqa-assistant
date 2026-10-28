// 液态玻璃材质层 —— 直接移植 SleepDown-Schedule 的 Kyant Backdrop 2.0 参数模型。
//
// 上游是 Jetpack Compose（AGSL RuntimeShader + RenderNode 采样）；这里用
// Flutter 的 Impeller 片元着色器（ImageFilter.shader）实现同一套折射方程，
// 材质 token 的数值逐条对齐 GlassMaterialSpec，所以两个 App 的玻璃读感一致。
//
// 与上游的对应关系：
//   GlassMaterialSpec        -> GlassMaterial
//   GlassMaterialSpec.pill   -> GlassMaterial.pill()
//   GlassMaterialSpec.dialog -> GlassMaterial.dialog()
//   GlassMaterialSpec.courseCard -> GlassMaterial.card()
//   GlassMaterialSpec.lens   -> GlassMaterial.lens()
//   RoundedRectRefraction*   -> shaders/liquid_glass.frag
//   DefaultHighlightShader   -> 同一 shader 的高光段
//   GlassInnerShadowFrame    -> 同一 shader 的内阴影段
//
// 没有 Impeller / 不支持 shader filter 时自动退回普通高斯模糊 + 半透明底色，
// 视觉降级但布局与交互不变。

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'glass.dart' show GlassScope;
import 'tokens.dart';

/// 一次绘制消费的全部材质参数（对齐上游 `GlassMaterialSpec`）。
@immutable
class GlassMaterial {
  const GlassMaterial({
    required this.role,
    this.blur = 4,
    this.lensHeight = 16,
    this.lensAmount = 32,
    this.surfaceAlpha = 0.40,
    this.borderAlpha = 0.28,
    this.highlightAlpha = 0.06,
    this.shadowAlpha = 0.18,
    this.innerShadowAlpha = 0.11,
    this.chromaticAberration = false,
    this.depthEffect = true,
    this.useVibrancy = true,
    this.highlightAngle = -math.pi / 2,
    this.highlightFalloff = 2.0,
  });

  final GlassRole role;
  final double blur;
  final double lensHeight;
  final double lensAmount;
  final double surfaceAlpha;
  final double borderAlpha;
  final double highlightAlpha;
  final double shadowAlpha;
  final double innerShadowAlpha;
  final bool chromaticAberration;
  final bool depthEffect;
  final bool useVibrancy;
  final double highlightAngle;
  final double highlightFalloff;

  /// `GlassMaterialSpec.pill`：Dock、胶囊按钮。
  factory GlassMaterial.pill({double intensity = 1}) {
    final k = intensity.clamp(0.4, 1.5).toDouble();
    return GlassMaterial(
      role: GlassRole.pill,
      blur: 2.5 * k,
      lensHeight: 12 * k,
      lensAmount: 24 * k,
      surfaceAlpha: 0.18,
      borderAlpha: 0.32,
      highlightAlpha: 0.055,
      shadowAlpha: 0.14,
      innerShadowAlpha: 0.09,
    );
  }

  /// `GlassMaterialSpec.dialog`：面板、卡片组、设置块。
  factory GlassMaterial.dialog({double intensity = 1}) {
    final k = intensity.clamp(0.4, 1.5).toDouble();
    return GlassMaterial(
      role: GlassRole.dialog,
      blur: 4 * k,
      lensHeight: 16 * k,
      lensAmount: 32 * k,
      surfaceAlpha: 0.40,
      borderAlpha: 0.28,
      highlightAlpha: 0.06,
      shadowAlpha: 0.18,
      innerShadowAlpha: 0.11,
    );
  }

  /// `GlassMaterialSpec.courseCard`：列表里的可点卡片。
  factory GlassMaterial.card({double blur = 8}) => GlassMaterial(
        role: GlassRole.card,
        blur: blur.clamp(0, 24).toDouble(),
        lensHeight: 10,
        lensAmount: 20,
        surfaceAlpha: 0.52,
        borderAlpha: 0.24,
        highlightAlpha: 0.045,
        shadowAlpha: 0.14,
        innerShadowAlpha: 0.10,
      );

  /// `GlassMaterialSpec.lens`：纯折射块，几乎不染色。
  factory GlassMaterial.lens() => const GlassMaterial(
        role: GlassRole.lens,
        blur: 3,
        lensHeight: 24,
        lensAmount: 34,
        surfaceAlpha: 0.08,
        borderAlpha: 0,
        highlightAlpha: 0.18,
        shadowAlpha: 0.34,
        innerShadowAlpha: 0.34,
        depthEffect: false,
      );

  /// `GlassMaterialSpec.popup`：菜单、浮层。
  factory GlassMaterial.popup({double blur = 10}) => GlassMaterial(
        role: GlassRole.popup,
        blur: blur,
        lensHeight: 12,
        lensAmount: 24,
        surfaceAlpha: 0.34,
        borderAlpha: 0.24,
        highlightAlpha: 0.06,
        shadowAlpha: 0.16,
        innerShadowAlpha: 0.10,
      );

  /// `GlassMaterialSpec.simpleBlur`：只模糊不折射（顶栏过渡、遮罩）。
  factory GlassMaterial.simpleBlur({double blur = 12}) => GlassMaterial(
        role: GlassRole.simpleBlur,
        blur: blur,
        lensHeight: 0,
        lensAmount: 0,
        surfaceAlpha: 0,
        borderAlpha: 0,
        highlightAlpha: 0.10,
        shadowAlpha: 0.12,
        innerShadowAlpha: 0.08,
        depthEffect: false,
        useVibrancy: false,
      );

  GlassMaterial copyWith({
    double? blur,
    double? lensHeight,
    double? lensAmount,
    double? surfaceAlpha,
    double? borderAlpha,
    double? highlightAlpha,
    double? shadowAlpha,
    double? innerShadowAlpha,
    double? highlightAngle,
    bool? chromaticAberration,
    bool? depthEffect,
    bool? useVibrancy,
  }) =>
      GlassMaterial(
        role: role,
        blur: blur ?? this.blur,
        lensHeight: lensHeight ?? this.lensHeight,
        lensAmount: lensAmount ?? this.lensAmount,
        surfaceAlpha: surfaceAlpha ?? this.surfaceAlpha,
        borderAlpha: borderAlpha ?? this.borderAlpha,
        highlightAlpha: highlightAlpha ?? this.highlightAlpha,
        shadowAlpha: shadowAlpha ?? this.shadowAlpha,
        innerShadowAlpha: innerShadowAlpha ?? this.innerShadowAlpha,
        chromaticAberration: chromaticAberration ?? this.chromaticAberration,
        depthEffect: depthEffect ?? this.depthEffect,
        useVibrancy: useVibrancy ?? this.useVibrancy,
        highlightAngle: highlightAngle ?? this.highlightAngle,
        highlightFalloff: highlightFalloff,
      );
}

/// 对应上游 `GlassMaterialRole`，用于按场景做策略分支。
enum GlassRole { pill, dialog, card, lens, popup, simpleBlur }

// ---------------------------------------------------------------------------
// 着色器生命周期
// ---------------------------------------------------------------------------

/// 持有已编译的折射着色器。App 启动时 await 一次 [GlassShader.load]。
class GlassShader {
  GlassShader._();

  static ui.FragmentProgram? _program;
  static bool _ready = false;
  static bool _shaderFilterOk = true;

  /// 着色器是否真的在跑（false 表示已降级为纯模糊）。
  static bool get isLive => _ready && _shaderFilterOk;

  static Future<void> load() async {
    if (_ready) return;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
      _shaderFilterOk = ui.ImageFilter.isShaderFilterSupported;
      _ready = true;
      debugPrint('GlassShader: loaded, filterSupported=$_shaderFilterOk');
    } catch (e, st) {
      _ready = false;
      _shaderFilterOk = false;
      debugPrint('GlassShader: shader unavailable, falling back to blur: $e\n$st');
    }
  }

  static ui.FragmentShader? newShader() => _program?.fragmentShader();
}

// ---------------------------------------------------------------------------
// 连续圆角（上游用 Kyant Shapes 的 G2 superellipse）
// ---------------------------------------------------------------------------

/// 构造连续曲率圆角矩形：角部不是 90° 圆弧拼接，而是两端切线连续的贝塞尔，
/// 观感与 SleepDown 的 G2 一致（比 `ClipRRect` 的圆角更"软"）。
Path continuousRoundedRect(Rect rect, double radius) {
  final r = math.min(radius, math.min(rect.width, rect.height) / 2);
  if (r <= 0) return Path()..addRect(rect);

  // 0.4477153 是 iOS squircle 的经典切点系数，让曲率在切点处连续。
  final h = r * 0.4477153;

  final path = Path();
  final l = rect.left, t = rect.top, rt = rect.right, b = rect.bottom;

  path.moveTo(l + r, t);
  path.lineTo(rt - r, t);
  path.cubicTo(rt - r + h, t, rt, t + r - h, rt, t + r);
  path.lineTo(rt, b - r);
  path.cubicTo(rt, b - r + h, rt - r + h, b, rt - r, b);
  path.lineTo(l + r, b);
  path.cubicTo(l + r - h, b, l, b - r + h, l, b - r);
  path.lineTo(l, t + r);
  path.cubicTo(l, t + r - h, l + r - h, t, l + r, t);
  path.close();
  return path;
}

// ---------------------------------------------------------------------------
// 主组件
// ---------------------------------------------------------------------------

/// 一块真正的液态玻璃。
///
/// 与常见"模糊 + 半透明白"的假玻璃不同，这里用 SDF 计算圆角边缘的折射位移，
/// 把背景按法线方向推开（`uRefractionAmount`），再叠表面染色、边缘高光与内阴影，
/// 四者合成一次片元输出。
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.material,
    this.radius = GlassRadius.panel,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.onTap,
    this.pressable = false,
    this.shadow = true,
    this.animate = true,
  });

  final Widget child;
  final GlassMaterial? material;
  final double radius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// 按下时按上游做法抬高高光、加深内阴影并轻微放大。
  final bool pressable;
  final bool shadow;

  /// 是否参与按压动画。
  final bool animate;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _p =
      CurvedAnimation(parent: _press, curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final base = widget.material ?? GlassMaterial.dialog();
    final m = base.copyWith(
      highlightAlpha: base.highlightAlpha + 0.10 * _p.value,
    );
    final radius = widget.radius;

    // 尺寸交给实际布局：Stack 先按内容定尺，Positioned.fill 再把玻璃铺满。
    Widget glass = Stack(
      children: [
        Positioned.fill(
          child: ClipPath(
            clipper: _RadiusClipper(radius),
            clipBehavior: Clip.antiAlias,
            child: _GlassSurface(material: m, ramp: ramp, radius: radius),
          ),
        ),
        Padding(padding: widget.padding, child: widget.child),
      ],
    );

    if (widget.onTap != null || widget.pressable) {
      glass = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (widget.animate) _press.forward();
        },
        onTapUp: (_) {
          if (widget.animate) _press.reverse();
        },
        onTapCancel: () {
          if (widget.animate) _press.reverse();
        },
        onTap: widget.onTap,
        child: glass,
      );
    }

    if (widget.margin != null) {
      glass = Padding(padding: widget.margin!, child: glass);
    }

    // 外阴影与边框在裁切外绘制，否则会被 clip 吃掉。
    return AnimatedBuilder(
      animation: _p,
      builder: (context, inner) => CustomPaint(
        foregroundPainter: _EdgePainter(
          material: m,
          ramp: ramp,
          radius: radius,
          press: _p.value,
        ),
        child: inner,
      ),
      child: glass,
    );
  }
}

class _RadiusClipper extends CustomClipper<Path> {
  const _RadiusClipper(this.radius);
  final double radius;
  @override
  Path getClip(Size size) => continuousRoundedRect(Offset.zero & size, radius);
  @override
  bool shouldReclip(_RadiusClipper oldClipper) => oldClipper.radius != radius;
}

/// 折射 + 染色 + 高光 + 内阴影，一次 shader 出结果。
class _GlassSurface extends StatelessWidget {
  const _GlassSurface({
    required this.material,
    required this.ramp,
    required this.radius,
  });

  final GlassMaterial material;
  final GlassRamp ramp;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (!GlassShader.isLive) {
      // 降级：普通模糊 + 半透明底色，观感接近但无折射。
      return BackdropFilter(
        filter: ui.ImageFilter.blur(
            sigmaX: material.blur, sigmaY: material.blur),
        child: ColoredBox(
          color: ramp.surface.withValues(alpha: material.surfaceAlpha),
        ),
      );
    }

    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 1.0;
        final h = c.maxHeight.isFinite ? c.maxHeight : 1.0;
        return BackdropFilter(
          filter: _buildFilter(Size(w, h), dpr),
          child: const SizedBox.expand(),
        );
      },
    );
  }

  ui.ImageFilter _buildFilter(Size size, double dpr) {
    final shader = GlassShader.newShader();
    if (shader == null) {
      return ui.ImageFilter.blur(
          sigmaX: material.blur, sigmaY: material.blur);
    }

    final w = (size.width * dpr).clamp(1.0, 8192.0);
    final h = (size.height * dpr).clamp(1.0, 8192.0);
    final rpx = radius * dpr;

    final highlight = ramp.highlight;

    void f(int i, double v) => shader.setFloat(i, v);

    f(0, w);                                  // uSize.x
    f(1, h);                                  // uSize.y
    f(2, w);                                  // uPanelSize.x
    f(3, h);                                  // uPanelSize.y
    f(4, 0);                                  // uInset.x
    f(5, 0);                                  // uInset.y
    f(6, rpx);                                // TL
    f(7, rpx);                                // TR
    f(8, rpx);                                // BR
    f(9, rpx);                                // BL
    f(10, material.lensHeight * dpr);         // refractionHeight
    f(11, material.lensAmount * dpr);         // refractionAmount
    f(12, material.depthEffect ? 1 : 0);
    f(13, material.chromaticAberration ? 1 : 0);
    f(14, material.highlightAngle);
    f(15, material.highlightFalloff);
    f(16, material.highlightAlpha);
    f(17, highlight.r);
    f(18, highlight.g);
    f(19, highlight.b);
    f(20, 1.0);
    f(21, ramp.surface.r);
    f(22, ramp.surface.g);
    f(23, ramp.surface.b);
    f(24, material.surfaceAlpha);
    f(25, material.innerShadowAlpha);
    f(26, 10 * dpr);
    f(27, material.useVibrancy ? 1 : 0);

    // 纹理模糊仍需一层高斯：上游是 blur → lens 两段。
    final blur = ui.ImageFilter.blur(
      sigmaX: material.blur * dpr * 0.5,
      sigmaY: material.blur * dpr * 0.5,
    );
    return ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(shader),
      inner: blur,
    );
  }
}

/// 外阴影 + 1px 玻璃切口 + 顶缘反光。
class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.material,
    required this.ramp,
    required this.radius,
    required this.press,
  });

  final GlassMaterial material;
  final GlassRamp ramp;
  final double radius;
  final double press;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = continuousRoundedRect(rect, radius);

    // 外阴影：上游 shadowAlpha 0.14~0.34，两层叠出体积。
    if (material.shadowAlpha > 0) {
      canvas.drawShadow(
        path,
        Colors.black.withValues(alpha: material.shadowAlpha * 0.55),
        6 + 4 * press,
        false,
      );
    }

    // 玻璃切口：1px 内描边，上亮下暗。
    if (material.borderAlpha > 0) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [
            Colors.white.withValues(alpha: material.borderAlpha),
            Colors.white.withValues(alpha: material.borderAlpha * 0.25),
          ],
        );
      canvas.drawPath(path, paint);
    }

    // 顶缘反光：一条渐隐的白色高光带。
    final sheenAlpha = (material.highlightAlpha + 0.10 * press).clamp(0.0, 1.0);
    if (sheenAlpha > 0.001) {
      canvas.save();
      canvas.clipPath(path);
      final band = Rect.fromLTWH(0, 0, size.width, size.height * 0.34);
      canvas.drawRect(
        band,
        Paint()
          ..shader = ui.Gradient.linear(
            band.topCenter,
            band.bottomCenter,
            [
              ramp.highlight.withValues(alpha: sheenAlpha * 1.6),
              ramp.highlight.withValues(alpha: 0),
            ],
          ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.material != material ||
      old.ramp != ramp ||
      old.radius != radius ||
      old.press != press;
}

// ---------------------------------------------------------------------------
// 按角色封装
// ---------------------------------------------------------------------------

/// 内容面板（对应上游 `LiquidPanel` 默认参数）。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(GlassGap.md),
    this.margin,
    this.radius = GlassRadius.panel,
    this.onTap,
    this.intensity = 1,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final double intensity;

  @override
  Widget build(BuildContext context) => LiquidGlass(
        material: GlassMaterial.dialog(intensity: intensity),
        radius: radius,
        padding: padding,
        margin: margin,
        onTap: onTap,
        pressable: onTap != null,
        child: child,
      );
}

/// 顶栏 / Dock 用的强染色玻璃。
class GlassChromeSurface extends StatelessWidget {
  const GlassChromeSurface({
    super.key,
    required this.child,
    this.radius = GlassRadius.sheet,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LiquidGlass(
        material: GlassMaterial.pill(intensity: 1.15).copyWith(
          surfaceAlpha: 0.26,
          lensHeight: 14,
          lensAmount: 28,
        ),
        radius: radius,
        padding: padding,
        child: child,
      );
}

/// 胶囊按钮，按下时高光抬升。
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
    this.dense = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final fg = selected ? Colors.white : ramp.content;
    return LiquidGlass(
      material: GlassMaterial.pill()
          .copyWith(surfaceAlpha: selected ? 0.30 : 0.18),
      radius: GlassRadius.pill,
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 12 : 16,
        vertical: dense ? 7 : 10,
      ),
      onTap: onTap,
      pressable: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 14 : 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GlassText.label.copyWith(color: fg, fontSize: dense ? 12 : 13),
          ),
        ],
      ),
    );
  }
}
