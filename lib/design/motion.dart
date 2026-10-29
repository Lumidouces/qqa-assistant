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

/// 标签页切换：任何时刻只画一页（IndexedStack 保状态），切页时给新页一个
/// 淡入 + 轻微上滑。
///
/// 之前是 Stack + 每页 AnimatedOpacity，并且用 TickerMode(enabled: active)
/// 包住——退出页的 ticker 被关掉，透明度动画卡死在 1.0，于是新旧两页
/// 永久叠在一起。IndexedStack 只绘制当前页，从根本上没有叠层可能。
class PageSwitcher extends StatefulWidget {
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
  State<PageSwitcher> createState() => _PageSwitcherState();
}

class _PageSwitcherState extends State<PageSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controller, curve: AppMotion.enter);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.02),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void didUpdateWidget(covariant PageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: IndexedStack(index: widget.index, children: widget.children),
      ),
    );
  }
}
