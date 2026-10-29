import 'dart:async';

import 'package:flutter/material.dart';

/// 统一的动效参数。
///
/// 曲线走「快出慢收」：前 30% 就把 70% 的距离走完，尾巴缓慢停住 —— 和
/// iOS 的 spring 落地手感接近，但不动用 physics 也能压在 60fps。
class AppMotion {
  const AppMotion._();

  /// 数字/文字替换。
  static const Duration fast = Duration(milliseconds: 180);

  /// 卡片入场、页面切换。
  static const Duration base = Duration(milliseconds: 260);

  /// 大块内容（Hero 卡、整页）入场。
  static const Duration slow = Duration(milliseconds: 420);

  /// 入场：起手快、收尾软。
  static const Curve enter = Cubic(0.16, 1, 0.3, 1);

  /// 退场要更快一点，避免两段重叠显脏。
  static const Curve exit = Cubic(0.4, 0, 1, 1);

  /// 从列表第 [index] 项开始，每项晚 [step] 出发。
  static Duration stagger(int index, {int step = 45}) =>
      Duration(milliseconds: (index * step).clamp(0, 600));
}

/// 一帧之后才进场 —— 让 [AnimatedSwitcher] / [AnimationController] 有起点值。
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.base,
    this.offset = 14,
    this.scaleFrom = 1,
    this.curve = AppMotion.enter,
    this.animate = true,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// 起始纵向位移（逻辑像素）。
  final double offset;

  /// 起始缩放，1 表示不缩放。
  final double scaleFrom;
  final Curve curve;
  final bool animate;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.animate ? 0 : 1,
  );
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 系统「减少动态效果」打开时直接给终值，不做动画。
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce && _controller.value != 1) {
      _timer?.cancel();
      _controller.value = 1;
      return;
    }
    if (!widget.animate || _controller.value > 0) return;
    _timer ??= Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
      reverseCurve: AppMotion.exit,
    );
    Widget child = FadeTransition(opacity: curved, child: widget.child);
    if (widget.offset != 0) {
      child = SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.offset / 100),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    }
    if (widget.scaleFrom != 1) {
      child = ScaleTransition(
        scale: Tween<double>(begin: widget.scaleFrom, end: 1).animate(curved),
        child: child,
      );
    }
    return child;
  }
}

/// 列表项错峰进场：第 n 项比第 n-1 项晚 [step] 毫秒。
class StaggerIn extends StatelessWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.step = 45,
    this.offset = 14,
    this.animate = true,
  });

  final int index;
  final Widget child;
  final int step;
  final double offset;
  final bool animate;

  @override
  Widget build(BuildContext context) => FadeSlideIn(
        delay: AppMotion.stagger(index, step: step),
        offset: offset,
        animate: animate,
        child: child,
      );
}

/// 文本值变化时上滑淡入 —— 用在计数器/用量这类会跳动的数字上。
class MorphText extends StatelessWidget {
  const MorphText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.alignment = Alignment.centerLeft,
    this.duration = AppMotion.fast,
  });

  final String text;
  final TextStyle? style;
  final int maxLines;
  final Alignment alignment;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [
          for (final child in previous) Positioned.fill(child: child),
          if (current != null) current,
        ],
      ),
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.45),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: Text(
        text,
        key: ValueKey<String>(text),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// 标签页切换：保留每页状态（不销毁滚动位置/输入），只做过场。
///
/// 未选中的页留在树里但 opacity 0、不吃事件、停 ticker —— 这样切回来是瞬时的，
/// 又不会让隐藏页的动画在后台空转烧电。
class PageSwitcher extends StatelessWidget {
  const PageSwitcher({
    super.key,
    required this.index,
    required this.children,
    this.duration = AppMotion.base,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var i = 0; i < children.length; i++)
          _PageSlot(
            active: i == index,
            first: true,
            duration: duration,
            child: children[i],
          ),
      ],
    );
  }
}

class _PageSlot extends StatefulWidget {
  const _PageSlot({
    required this.active,
    required this.first,
    required this.duration,
    required this.child,
  });

  final bool active;
  final bool first;
  final Duration duration;
  final Widget child;

  @override
  State<_PageSlot> createState() => _PageSlotState();
}

class _PageSlotState extends State<_PageSlot> {
  /// 第一次被选中之前一直是 false，避免隐藏页在后台跑入场动画。
  bool _warm = false;

  @override
  void initState() {
    super.initState();
    _warm = widget.active;
  }

  @override
  void didUpdateWidget(covariant _PageSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_warm) setState(() => _warm = true);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return IgnorePointer(
      ignoring: !active,
      child: TickerMode(
        enabled: active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: widget.duration,
          curve: active ? AppMotion.enter : AppMotion.exit,
          child: AnimatedSlide(
            offset: active ? Offset.zero : const Offset(0, 0.02),
            duration: widget.duration,
            curve: active ? AppMotion.enter : AppMotion.exit,
            child: TickerMode(
              enabled: active,
              // 未预热过的页先画出来但透明，等真正选中再淡入。
              child: _warm ? widget.child : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
