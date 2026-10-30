import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../widgets.dart';
import '../../design/motion.dart';
import '../../core/tokens_fmt.dart';

/// 总览 — status hero, the four counters, usage, and the shortcut strip.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  final AppState state;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final labels = state.heroLabels();
    final connection = labels['connectionLabel'] ?? '控制台未连接';
    final botLabel = labels['botLabel'] ?? 'DSH 未运行';
    final online = labels['accent'] == 'ok';

    // 顶层分区按顺序错峰进场：第一屏读起来有层次，而不是一坨同时亮。
    final sections = <Widget>[
      _TopBar(state: state),
      const SizedBox(height: GlassGap.md),
      HeroCard(
        title: state.account.label,
        connectionLabel: '$connection',
        online: online,
        botLabel: '$botLabel',
        botOnline: online,
        chips: [
          Chip2(
            text: state.account.origin.replaceFirst('https://', ''),
            icon: Icons.link_rounded,
          ),
          if (state.status.botNickname.isNotEmpty)
            Chip2(
              text: state.status.botNickname,
              icon: Icons.smart_toy_rounded,
            ),
          if (state.status.model.isNotEmpty)
            Chip2(
              text: state.status.model,
              icon: Icons.memory_rounded,
              color: ramp.accentDeep,
            ),
        ],
        footnote: '最近更新 ${relativeTime(state.lastUpdated)} · '
            '每 ${state.refreshSeconds} 秒轮询',
        onRefresh: state.refreshStatus,
      ),
      if (state.statusError != null) ...[
        const SizedBox(height: GlassGap.sm),
        _ErrorBar(message: state.statusError!),
      ],
      const SizedBox(height: GlassGap.sm),
      MetricCard(children: [
        Tile(
          label: '已收消息',
          value: '${labels['calls'] ?? '—'}',
          hint: '本轮调用次数',
        ),
        Tile(
          label: '已回复',
          value: state.status.paused ? '暂停' : '${state.repliedCount}',
          hint: '${state.sessions.length} 条会话',
          valueColor: ramp.accent,
        ),
        Tile(
          label: '未回复',
          value: '${state.filteredCount}',
          hint: '规则命中 / 跳过',
        ),
        Tile(
          label: '进行中',
          value: '${state.runningCount}',
          hint: state.runningCount > 0 ? '正在处理' : '发送正常',
        ),
      ]),
      const SizedBox(height: GlassGap.sm),
      _UsageCard(state: state),
      const SizedBox(height: GlassGap.sm),
      _QuickStrip(onNavigate: onNavigate),
    ];

    return RefreshIndicator(
      color: ramp.accent,
      backgroundColor: ramp.page,
      onRefresh: state.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            GlassGap.pageH, 12, GlassGap.pageH, GlassGap.dockInset),
        children: [
          for (var i = 0; i < sections.length; i++)
            StaggerIn(index: i, child: sections[i]),
        ],
      ),
    );
  }
}

/// Compact header above the hero: app name, connection state, two icon actions.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QQA 助手',
                  style: GlassText.display
                      .copyWith(color: ramp.content, fontSize: 27)),
              const SizedBox(height: 4),
              Text(
                state.account.origin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GlassText.mono.copyWith(color: ramp.contentFaint),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GlassChrome(
          radius: GlassRadius.pill,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _IconAction(
                icon: Icons.refresh_rounded,
                tooltip: '刷新',
                onTap: state.refreshAll,
              ),
              _IconAction(
                icon: Icons.logout_rounded,
                tooltip: '断开连接',
                onTap: state.disconnectActive,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 19, color: ramp.contentMuted),
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final labels = state.heroLabels();
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    return GlassPanel(
      radius: GlassRadius.panel,
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 17),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 27,
                height: 27,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ramp.accent.withValues(alpha: 0.12),
                  border: Border.all(
                      color: ramp.accent.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.trending_up_rounded,
                    size: 14, color: ramp.accent),
              ),
              const SizedBox(width: 10),
              Text('用量', style: GlassText.title.copyWith(color: ramp.content)),
              const Spacer(),
              Text(date,
                  style: GlassText.mono.copyWith(color: ramp.contentFaint)),
            ],
          ),
          const SizedBox(height: GlassGap.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Tile(
                  label: '总 tokens',
                  value: formatTokensBare(state.status.totalTokens,
                      scale: state.tokenScale),
                  hint: '入 ${formatTokensBare(state.status.promptTokens, scale: state.tokenScale)}'
                      ' · 出 ${formatTokensBare(state.status.completionTokens, scale: state.tokenScale)}',
                  onTap: state.cycleTokenScale,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Tile(
                  label: '轮次',
                  value: '${state.status.calls}',
                  hint: '缓存命中 ${labels['hitRate'] ?? '—'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Tile(
                  label: '花费',
                  value: state.status.cost > 0
                      ? '¥${state.status.cost.toStringAsFixed(2)}'
                      : '—',
                  hint: state.status.model.isEmpty ? '未上报' : state.status.model,
                  valueColor: ramp.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Tile(
                  label: '缓存读',
                  value: formatTokensBare(state.status.cacheReadTokens,
                      scale: state.tokenScale),
                  hint: '命中 ${labels['hitRate'] ?? '—'}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shortcut tiles that jump to the other tabs.
class _QuickStrip extends StatelessWidget {
  const _QuickStrip({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    const items = <({String label, IconData icon, int tab})>[
      (label: '会话过程', icon: Icons.forum_outlined, tab: 1),
      (label: '用量日志', icon: Icons.insights_outlined, tab: 2),
      (label: '消息存档', icon: Icons.chat_bubble_outline_rounded, tab: 3),
      (label: '操作', icon: Icons.bolt_outlined, tab: 4),
      (label: '设置', icon: Icons.settings_outlined, tab: 5),
    ];
    return GlassPanel(
      radius: GlassRadius.panel,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassSectionHeader(title: '常用入口'),
          Row(
            children: [
              for (final item in items)
                Expanded(
                  child: _QuickTile(
                    label: item.label,
                    icon: item.icon,
                    onTap: () => onNavigate(item.tab),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ramp.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(GlassRadius.chip),
                border: Border.all(
                    color: ramp.accent.withValues(alpha: 0.20)),
              ),
              child: Icon(icon, size: 19, color: ramp.accent),
            ),
            const SizedBox(height: 7),
            Text(label,
                style: GlassText.caption.copyWith(color: ramp.contentMuted)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFE5484D);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(GlassRadius.chip),
        border: Border.all(color: danger.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message,
                style: GlassText.caption.copyWith(color: danger)),
          ),
        ],
      ),
    );
  }
}
