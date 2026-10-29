// SleepDown-Schedule `LiquidBottomTabs` 的 Flutter 移植。
//
// 上游是 Kyant0/AndroidLiquidGlass 的 catalog 组件（Apache-2.0），SleepDown
// 在 `LiquidOptionTabs.kt` / `HomeDockTabs.kt` 里用它做设置页分段和底部 Dock。
// 这里把它逐项搬过来，包括那套让"指示器像一块玻璃在液体里滑动"的动画：
//
//   1. DampedDragAnimation —— 指示器位置是一个受弹簧驱动的连续浮点值，
//      拖动时跟手、松手后按 spring(1, 1000) 吸附到最近格子；
//   2. 按下时指示器整体放大到 78/56，同时把 lens 折射量从 0 拉到满值，
//      所以手指按住的那一刻玻璃才会"凸"起来；
//   3. 移动高光（InteractiveHighlight）—— 一团跟着指示器走的径向光斑，
//      让胶囊在滑动过程中有被光照到的读感；
//   4. 容器与指示器都是两段式材质：容器 blur + lens，指示器纯 lens + 色差。
//
// 数值全部对齐上游 `HomeDockTabs` 的调用参数。

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'glass.dart';

/// 一个格子要显示什么。
@immutable
class LiquidTabSpec {
  const LiquidTabSpec({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// 液态玻璃分段标签栏 / Dock。
///
/// 宽度由父级约束决定，内部按 [tabs] 数量均分；高度默认 54，指示器 46。
class LiquidTabBar extends StatefulWidget {
  const LiquidTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelect,
    this.height = 54,
    this.indicatorHeight = 46,
    this.horizontalPadding = 4,
    this.indicatorWidthOverflow = 8,
    this.indicatorHeightOverflow = 4,
    this.chromaticAberration = true,
    this.showLabels = true,
    this.iconSize = 22,
    this.labelSize = 10,
  });

  final List<LiquidTabSpec> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  final double height;
  final double indicatorHeight;
  final double horizontalPadding;

  /// 指示器比格子宽/高出来多少（上游 `indicatorWidthOverflow` 等）。
  final double indicatorWidthOverflow;
  final double indicatorHeightOverflow;

  final bool chromaticAberration;
  final bool showLabels;
  final double iconSize;
  final double labelSize;

  @override
  State<LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<LiquidTabBar>
    with TickerProviderStateMixin {
  /// 指示器所在的连续位置（0 .. n-1）。上游 DampedDragAnimation 的同名量。
  late final AnimationController _pos = AnimationController.unbounded(
    vsync: this,
    value: widget.index.toDouble(),
  );

  /// 按下进度 0..1，驱动放大与 lens 强度。
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
    value: 0,
  );

  /// 手指横向位置（相对本控件），用于移动高光。
  double? _pointerX;
  bool _dragging = false;

  static final SpringDescription _valueSpring =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1000,
    ratio: 1,
  );

  static final SpringDescription _pressSpring =
      SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 1000,
    ratio: 1,
  );

  @override
  void didUpdateWidget(covariant LiquidTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index && !_dragging) {
      _animateTo(widget.index.toDouble());
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    _press.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _pos.animateWith(SpringSimulation(_valueSpring, _pos.value, target, 0));
  }

  void _setPress(double target) {
    _press.animateWith(SpringSimulation(_pressSpring, _press.value, target, 0));
  }

  void _onDragUpdate(DragUpdateDetails details, double tabWidth) {
    _pos.value = (_pos.value + details.delta.dx / tabWidth)
        .clamp(0.0, (widget.tabs.length - 1).toDouble());
    setState(() => _pointerX = details.localPosition.dx);
  }

  void _onDragEnd(double tabWidth) {
    final target = _pos.value.round().clamp(0, widget.tabs.length - 1);
    _dragging = false;
    _animateTo(target.toDouble());
    if (target != widget.index) widget.onSelect(target);
  }

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final dark = GlassScope.of(context).isDark;
    final n = widget.tabs.length;

    // 容器：blur 4 + lens 10/40，alpha 0.4（上游 containerAlpha）。
    // 高光/阴影用上游 official* 三个值（0.07 / 0.05 / 0.08）——
    // 传 1 会让暗色主题下整块胶囊被顶缘反光刷成白板。
    final container = GlassMaterial.pill(intensity: 1).copyWith(
      blur: 4,
      lensHeight: 10,
      lensAmount: 40,
      surfaceAlpha: 0.40,
      borderAlpha: 0,
      highlightAlpha: 0.07,
      shadowAlpha: 0.05,
      innerShadowAlpha: 0.08,
      chromaticAberration: widget.chromaticAberration,
      depthEffect: false,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tabWidth =
            (width - widget.horizontalPadding * 2) / n;

        return AnimatedBuilder(
          animation: Listenable.merge([_pos, _press]),
          builder: (context, _) {
            final press = _press.value.clamp(0.0, 1.0);
            // 上游 pressedScale = 78/56。
            final scale = 1 + (78 / 56 - 1) * press;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                setState(() => _pointerX = d.localPosition.dx);
                _setPress(1);
              },
              onTapUp: (_) => _setPress(0),
              onTapCancel: () => _setPress(0),
              onTap: () {
                final target = ((_pointerX ?? 0) - widget.horizontalPadding) ~/
                    tabWidth;
                final clamped = target.clamp(0, n - 1);
                if (clamped != widget.index) widget.onSelect(clamped);
              },
              onHorizontalDragStart: (d) {
                _dragging = true;
                _setPress(1);
                setState(() => _pointerX = d.localPosition.dx);
              },
              onHorizontalDragUpdate: (d) => _onDragUpdate(d, tabWidth),
              onHorizontalDragEnd: (_) {
                _onDragEnd(tabWidth);
                _setPress(0);
              },
              onHorizontalDragCancel: () {
                _onDragEnd(tabWidth);
                _setPress(0);
              },
              child: SizedBox(
                height: widget.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ---- 容器胶囊 ----
                    Positioned.fill(
                      child: LiquidGlass(
                        material: container,
                        radius: GlassRadius.pill,
                        animate: false,
                        child: const SizedBox.expand(),
                      ),
                    ),

                    // ---- 滑动指示器 ----
                    Positioned(
                      left: widget.horizontalPadding +
                          _pos.value * tabWidth -
                          widget.indicatorWidthOverflow * press / 2,
                      top: (widget.height -
                              widget.indicatorHeight -
                              widget.indicatorHeightOverflow * press) /
                          2,
                      width:
                          tabWidth + widget.indicatorWidthOverflow * press,
                      height: widget.indicatorHeight +
                          widget.indicatorHeightOverflow * press,
                      child: Transform.scale(
                        scaleX: scale,
                        scaleY: scale,
                        child: _Indicator(
                          ramp: ramp,
                          dark: dark,
                          press: press,
                          chromaticAberration: widget.chromaticAberration,
                        ),
                      ),
                    ),

                    // ---- 移动高光 ----
                    if (press > 0.01 && _pointerX != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _HighlightPainter(
                              center: Offset(_pointerX!, widget.height / 2),
                              alpha: press * 0.10,
                              color: dark ? Colors.white : Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // ---- 内容 ----
                    Row(
                      children: [
                        SizedBox(width: widget.horizontalPadding),
                        for (var i = 0; i < n; i++)
                          SizedBox(
                            width: tabWidth,
                            height: widget.height,
                            child: _TabCell(
                              spec: widget.tabs[i],
                              selected: i == _pos.value.round(),
                              ramp: ramp,
                              scale: 1 +
                                  (78 / 56 - 1) *
                                      press *
                                      (_isNear(i, tabWidth) ? 1 : 0),
                              showLabel: widget.showLabels,
                              iconSize: widget.iconSize,
                              labelSize: widget.labelSize,
                              onTap: () => widget.onSelect(i),
                            ),
                          ),
                        SizedBox(width: widget.horizontalPadding),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 按下时只有手指底下那一格放大（上游 `LocalLiquidBottomTabScale`）。
  bool _isNear(int index, double tabWidth) {
    final x = _pointerX;
    if (x == null) return false;
    final center = widget.horizontalPadding + (index + 0.5) * tabWidth;
    return (x - center).abs() <= tabWidth / 2;
  }
}

/// 指示器本体：纯 lens + 色差，几乎不染色。
class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.ramp,
    required this.dark,
    required this.press,
    required this.chromaticAberration,
  });

  final GlassRamp ramp;
  final bool dark;
  final double press;
  final bool chromaticAberration;

  @override
  Widget build(BuildContext context) {
    // 上游 indicatorMaterial：blur 0，lens 12/17（official），surfaceAlpha 0.1，
    // 高光/阴影/内阴影都乘 press。
    final material = GlassMaterial.pill(intensity: 1).copyWith(
      blur: 0,
      lensHeight: 12 * press,
      lensAmount: 17 * press,
      surfaceAlpha: 0.10,
      borderAlpha: 0,
      highlightAlpha: 0.07 * press,
      shadowAlpha: 0.05 * press,
      innerShadowAlpha: 0.08 * press,
      chromaticAberration: chromaticAberration,
      depthEffect: false,
      useVibrancy: false,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: LiquidGlass(
            material: material,
            radius: GlassRadius.pill,
            animate: false,
            shadow: false,
            child: const SizedBox.expand(),
          ),
        ),
        // 未按下时指示器仍要能看见：一层极淡的中性色。
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: (dark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.10 * (1 - press)),
                borderRadius: BorderRadius.circular(GlassRadius.pill),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabCell extends StatelessWidget {
  const _TabCell({
    required this.spec,
    required this.selected,
    required this.ramp,
    required this.scale,
    required this.showLabel,
    required this.iconSize,
    required this.labelSize,
    required this.onTap,
  });

  final LiquidTabSpec spec;
  final bool selected;
  final GlassRamp ramp;
  final double scale;
  final bool showLabel;
  final double iconSize;
  final double labelSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ramp.content : ramp.contentFaint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(spec.icon, size: iconSize, color: color),
              if (showLabel) ...[
                const SizedBox(height: 2),
                Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: labelSize,
                    height: 1.1,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 上游 `InteractiveHighlight`：一团跟着手指走的柔光。
class _HighlightPainter extends CustomPainter {
  const _HighlightPainter({
    required this.center,
    required this.alpha,
    required this.color,
  });

  final Offset center;
  final double alpha;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.height * 1.4;
    final paint = Paint()
      ..shader = _uiRadial(center, radius, color, alpha);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.center != center || old.alpha != alpha;
}

Shader _uiRadial(Offset center, double radius, Color color, double alpha) {
  return RadialGradient(
    colors: [
      color.withValues(alpha: alpha),
      color.withValues(alpha: 0),
    ],
  ).createShader(Rect.fromCircle(center: center, radius: radius));
}

/// 便捷构造：从标签+图标列表造出 [LiquidTabSpec]。
List<LiquidTabSpec> liquidTabsOf(
  List<String> labels,
  List<IconData> icons,
) {
  assert(labels.length == icons.length);
  return [
    for (var i = 0; i < labels.length; i++)
      LiquidTabSpec(icon: icons[i], label: labels[i]),
  ];
}
