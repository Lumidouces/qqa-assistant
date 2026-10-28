// App-level composites built on top of the glass primitives.
//
// These keep the shape the screens already talk to (`HeroCard`, `MetricCard`,
// `Tile`, ...) but render through `design/glass.dart`, so the whole app inherits
// the SleepDown liquid-glass material without each screen re-implementing it.

import 'package:flutter/material.dart';

import '../design/glass.dart';

export '../design/glass.dart';

/// Section heading: title on the left, optional action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) =>
      GlassSectionHeader(title: title, subtitle: subtitle, trailing: trailing);
}

/// Small translucent tag, e.g. `SSH 隧道` / `deepseek-flash`.
class Chip2 extends StatelessWidget {
  const Chip2({
    super.key,
    required this.text,
    this.icon,
    this.color,
    this.dense = false,
  });

  final String text;
  final IconData? icon;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) => GlassChip(
        text: text,
        icon: icon,
        color: color,
        dense: dense,
      );
}

/// `● 控制台已连接` style dot + label.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.text,
    this.color,
    this.fontSize = 13,
  });

  final String text;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final tint = color ?? ramp.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.5,
          height: 7.5,
          decoration: BoxDecoration(
            color: tint,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: tint.withValues(alpha: 0.55), blurRadius: 7),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tint,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}

/// The large status panel at the top of the overview.
///
/// SleepDown's equivalent is the "today" hero: an accent-tinted glass slab with
/// a heavy display line, a row of chips, and one quiet footnote.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.title,
    required this.connectionLabel,
    required this.online,
    required this.botLabel,
    required this.botOnline,
    required this.chips,
    required this.footnote,
    this.onRefresh,
  });

  final String title;
  final String connectionLabel;
  final bool online;
  final String botLabel;
  final bool botOnline;
  final List<Widget> chips;
  final String footnote;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final accent = online ? ramp.accent : const Color(0xFFE0A93B);

    return GlassPanel(
      radius: GlassRadius.panel,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      tint: ramp.panelTint + 0.06,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatusDot(
                  text: connectionLabel,
                  color: accent,
                  fontSize: 13,
                ),
              ),
              if (onRefresh != null)
                GestureDetector(
                  onTap: onRefresh,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.refresh_rounded,
                        size: 19, color: ramp.contentMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GlassText.display.copyWith(color: ramp.content),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
          const SizedBox(height: 10),
          GlassChip(
            text: botLabel,
            dotColor: botOnline ? ramp.accent : const Color(0xFFE0A93B),
          ),
          const SizedBox(height: 14),
          Text(
            footnote,
            style: GlassText.caption.copyWith(color: ramp.contentFaint),
          ),
        ],
      ),
    );
  }
}

/// Card that holds a grid of [Tile]s.
class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.children, this.columns = 2});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var index = 0; index < children.length; index += columns) {
      final slice = children.skip(index).take(columns).toList();
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var column = 0; column < columns; column++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: column == columns - 1 ? 0 : 10,
                  bottom: index + columns < children.length ? 20 : 0,
                ),
                child: column < slice.length ? slice[column] : const SizedBox(),
              ),
            ),
        ],
      ));
    }
    return GlassPanel(
      radius: GlassRadius.panel,
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 17),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }
}

/// Labelled figure used inside [MetricCard].
class Tile extends StatelessWidget {
  const Tile({
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GlassMetric(
        label: label,
        value: value,
        hint: hint,
        valueColor: valueColor,
        onTap: onTap,
      );
}

/// Hairline switch row used by the settings screen.
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassPanel(
        radius: GlassRadius.chip,
        padding: const EdgeInsets.fromLTRB(15, 13, 9, 13),
        tint: ramp.panelTint - 0.06,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GlassText.body.copyWith(
                          color: ramp.content,
                          fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!,
                        style: GlassText.caption
                            .copyWith(color: ramp.contentFaint)),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: ramp.accent,
              inactiveTrackColor: ramp.content.withValues(alpha: 0.12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filled capsule action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
    this.expand = false,
    this.danger = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool expand;
  final bool danger;

  @override
  Widget build(BuildContext context) => GlassButton(
        label: label,
        icon: icon,
        onTap: onPressed,
        busy: busy,
        expand: expand,
        tone: danger ? GlassButtonTone.danger : GlassButtonTone.accent,
      );
}

/// Quiet outlined action.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => GlassButton(
        label: label,
        icon: icon,
        onTap: onPressed,
        tone: GlassButtonTone.quiet,
      );
}

/// Empty / error placeholder used by every list.
class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.title,
    this.detail,
    this.icon = Icons.inbox_rounded,
    this.onRetry,
  });

  final String title;
  final String? detail;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: GlassRadius.panel,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          GlassEmpty(icon: icon, title: title, hint: detail),
          if (onRetry != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: GhostButton(
                label: '重试',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ),
        ],
      ),
    );
  }
}

/// Relative timestamp such as `3 分钟前`.
String relativeTime(DateTime? at) {
  if (at == null) return '还没更新';
  final gap = DateTime.now().difference(at);
  if (gap.inSeconds < 10) return '刚刚';
  if (gap.inSeconds < 60) return '${gap.inSeconds} 秒前';
  if (gap.inMinutes < 60) return '${gap.inMinutes} 分钟前';
  if (gap.inHours < 24) return '${gap.inHours} 小时前';
  return '${gap.inDays} 天前';
}

/// Clock formatter shared by the log rows: `14:32` or `10-27 14:32`.
String stampTime(int? millis) {
  if (millis == null || millis <= 0) return '—';
  final at = DateTime.fromMillisecondsSinceEpoch(millis);
  final hh = at.hour.toString().padLeft(2, '0');
  final mm = at.minute.toString().padLeft(2, '0');
  final now = DateTime.now();
  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  if (sameDay) return '$hh:$mm';
  final mo = at.month.toString().padLeft(2, '0');
  final dd = at.day.toString().padLeft(2, '0');
  return '$mo-$dd $hh:$mm';
}
