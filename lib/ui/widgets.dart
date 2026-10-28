import 'package:flutter/material.dart';

import '../theme.dart';

/// Small rounded label such as `SSH 隧道` / `deepseek-flash`.
class Chip2 extends StatelessWidget {
  const Chip2({
    super.key,
    required this.text,
    this.icon,
    this.color = QqaColors.accent,
    this.dense = false,
  });

  final String text;
  final IconData? icon;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10, vertical: dense ? 4 : 6),
      decoration: QqaDecor.pill(color: color, alpha: 0.12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `● 控制台已连接` style dot + label.
class StatusDot extends StatelessWidget {
  const StatusDot({
    super.key,
    required this.text,
    this.color = QqaColors.accent,
    this.fontSize = 13,
  });

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 6),
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
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// The big gradient hero card at the top of the overview.
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
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: QqaColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: QqaColors.accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: QqaColors.accent.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: StatusDot(
                  text: connectionLabel,
                  color: online ? QqaColors.accent : QqaColors.warn,
                  fontSize: 13.5,
                ),
              ),
              if (onRefresh != null)
                InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(999),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.refresh_rounded,
                        size: 20, color: QqaColors.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: (botOnline ? QqaColors.accent : QqaColors.warn)
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: (botOnline ? QqaColors.accent : QqaColors.warn)
                      .withValues(alpha: 0.5),
                ),
              ),
              child: StatusDot(
                text: botLabel,
                color: botOnline ? QqaColors.accent : QqaColors.warn,
                fontSize: 12.5,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            footnote,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card that holds a `MetricTile` grid.
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
                    bottom: index + columns < children.length ? 18 : 0),
                child: column < slice.length ? slice[column] : const SizedBox(),
              ),
            ),
        ],
      ));
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: QqaDecor.card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }
}

/// Labelled tile used inside [MetricCard].
class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.label,
    required this.value,
    this.hint,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? hint;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: QqaText.muted),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: QqaText.metric
              .copyWith(color: valueColor ?? QqaColors.text, fontSize: 24),
        ),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(hint!, style: QqaText.key, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: QqaDecor.card(radius: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: QqaText.body),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: QqaText.muted),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: QqaColors.accent,
          ),
        ],
      ),
    );
  }
}

/// Filled action button (mint on black).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: QqaColors.bg),
          )
        else if (icon != null)
          Icon(icon, size: 17, color: QqaColors.bg),
        if (busy || icon != null) const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: QqaColors.bg,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return SizedBox(
      width: expand ? double.infinity : null,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: QqaColors.accent,
          disabledBackgroundColor: QqaColors.accent.withValues(alpha: 0.4),
          foregroundColor: QqaColors.bg,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      ),
    );
  }
}

/// Ghost button (outline on black).
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
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: QqaColors.text,
        side: const BorderSide(color: QqaColors.line),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
      decoration: QqaDecor.card(),
      child: Column(
        children: [
          Icon(icon, size: 30, color: QqaColors.faint),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: QqaText.body),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail!, textAlign: TextAlign.center, style: QqaText.muted),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            GhostButton(label: '重试', icon: Icons.refresh_rounded, onPressed: onRetry),
          ],
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
