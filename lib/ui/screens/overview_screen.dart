import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
import '../widgets.dart';

/// 总览 · the hero card plus everything the mock-up shows on one screen.
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
    final labels = state.heroLabels();
    final connections = labels['connectionLabel'] ?? '控制台未连接';
    final botLabel = labels['botLabel'] ?? 'DSH 未运行';
    final accent = labels['accent'];
    final online = accent == 'ok';

    return RefreshIndicator(
      color: QqaColors.accent,
      backgroundColor: QqaColors.surface,
      onRefresh: state.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
        children: [
          _Header(state: state),
          const SizedBox(height: 14),
          HeroCard(
            title: state.account.label,
            connectionLabel: '$connections',
            online: online,
            botLabel: '$botLabel',
            botOnline: online,
            chips: [
              Chip2(
                text: state.account.origin.replaceFirst('https://', ''),
                icon: Icons.link_rounded,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              if (state.status.botNickname.isNotEmpty)
                Chip2(
                  text: state.status.botNickname,
                  icon: Icons.smart_toy_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              if (state.status.model.isNotEmpty)
                Chip2(
                  text: state.status.model,
                  icon: Icons.memory_rounded,
                  color: QqaColors.info,
                ),
            ],
            footnote: '最近更新 ${relativeTime(state.lastUpdated)}',
            onRefresh: state.refreshStatus,
          ),
          if (state.statusError != null) ...[
            const SizedBox(height: 12),
            _ErrorBar(message: state.statusError!),
          ],
          const SizedBox(height: 12),
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
              valueColor: QqaColors.accent,
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
          const SizedBox(height: 12),
          _UsageCard(state: state),
          const SizedBox(height: 12),
          _QuickStrip(onNavigate: onNavigate),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: state.status.connected
                          ? QqaColors.accent
                          : QqaColors.faint,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      state.account.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: QqaColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Text(
                  '${state.account.origin} · ${state.refreshSeconds} 秒刷新',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: QqaText.key,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: state.refreshAll,
          icon: const Icon(Icons.refresh_rounded, size: 21),
          color: QqaColors.muted,
        ),
        IconButton(
          onPressed: state.disconnectActive,
          icon: const Icon(Icons.logout_rounded, size: 21),
          color: QqaColors.muted,
          tooltip: '断开连接',
        ),
      ],
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final labels = state.heroLabels();
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: QqaDecor.card(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: QqaColors.accent.withValues(alpha: 0.55), width: 2),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    size: 13, color: QqaColors.accent),
              ),
              const SizedBox(width: 10),
              const Text('用量', style: QqaText.title),
              const Spacer(),
              Text(date, style: QqaText.key),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Tile(
                  label: '总 tokens',
                  value: '${labels['totalTokens'] ?? '—'}',
                  hint: '入 ${state.status.promptTokens} · 出 ${state.status.completionTokens}',
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
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Tile(
                  label: '花费',
                  value: state.status.cost > 0
                      ? '¥${state.status.cost.toStringAsFixed(2)}'
                      : '—',
                  hint: state.status.model.isEmpty
                      ? '未上报'
                      : state.status.model,
                  valueColor: QqaColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Tile(
                  label: '缓存读',
                  value: '${state.status.cacheReadTokens}',
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

/// Four shortcut rows that jump to the other tabs.
class _QuickStrip extends StatelessWidget {
  const _QuickStrip({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    const items = <({String label, IconData icon, int tab})>[
      (label: '会话过程', icon: Icons.forum_outlined, tab: 1),
      (label: '消息存档', icon: Icons.chat_bubble_outline_rounded, tab: 2),
      (label: '操作', icon: Icons.tune_rounded, tab: 3),
      (label: '设置', icon: Icons.settings_outlined, tab: 4),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: QqaDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('常用入口', style: QqaText.title),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final item in items)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onNavigate(item.tab),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Icon(item.icon, size: 20, color: QqaColors.accent),
                          const SizedBox(height: 7),
                          Text(item.label,
                              style: const TextStyle(
                                  color: QqaColors.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: QqaColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: QqaColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 16, color: QqaColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style:
                    const TextStyle(color: QqaColors.danger, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
