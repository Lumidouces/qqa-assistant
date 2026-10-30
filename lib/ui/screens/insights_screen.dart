import 'package:flutter/material.dart';

import '../../core/insights.dart';
import '../../core/tokens_fmt.dart';
import '../../design/motion.dart';
import '../../state/app_state.dart';
import '../widgets.dart';

/// 剖析 · 0.5 控制台新增的两组只读接口：用量统计（`/api/usage/stats`）与
/// 运行日志（`/api/logs`）。
///
/// 手机上最常问的两个问题是「这个月花了多少」和「它为什么不回消息」，
/// 前者对应第一页，后者对应第二页，所以两页放在同一个标签里。
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  static const _ranges = [
    (wire: '1', label: '今天'),
    (wire: '7', label: '7 天'),
    (wire: '30', label: '30 天'),
  ];

  /// 0 = 用量，1 = 日志。
  int _page = 0;
  bool _loadedUsage = false;
  bool _loadedLogs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  void _loadAll() {
    if (!mounted) return;
    final state = widget.state;
    if (!state.ready) return;
    if (!_loadedUsage) {
      _loadedUsage = true;
      state.loadUsage();
    }
    if (!_loadedLogs) {
      _loadedLogs = true;
      state.loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return RefreshIndicator(
      color: GlassScope.rampOf(context).accent,
      backgroundColor: GlassScope.rampOf(context).page,
      onRefresh: () async {
        if (_page == 0) {
          await state.loadUsage();
        } else {
          await state.loadLogs();
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          GlassGap.pageH,
          16,
          GlassGap.pageH,
          GlassGap.dockInset,
        ),
        children: [
          _PageSwitch(
            page: _page,
            onSelect: (value) {
              setState(() => _page = value);
              _loadAll();
            },
          ),
          const SizedBox(height: 14),
          if (_page == 0) ..._usageSections(state) else ..._logSections(state),
        ],
      ),
    );
  }

  // ————————————————————————————— 用量 —————————————————————————————

  List<Widget> _usageSections(AppState state) {
    final ramp = GlassScope.rampOf(context);
    final usage = state.usage;
    final sections = <Widget>[
      GlassSectionHeader(
        title: '用量',
        subtitle: usage.rangeLabel.isEmpty
            ? '控制台记录的 token 与花费'
            : usage.rangeLabel,
        trailing: state.loadingUsage
            ? SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ramp.accent,
                ),
              )
            : null,
      ),
      _RangeSwitch(
        ranges: _ranges,
        selected: state.usageRange,
        onSelect: (wire) => state.loadUsage(range: wire),
      ),
      const SizedBox(height: 12),
    ];

    if (state.usageError != null) {
      sections.add(
        EmptyHint(
          title: '读取用量失败',
          detail: state.usageError,
          icon: Icons.cloud_off_rounded,
          onRetry: state.loadUsage,
        ),
      );
      return sections;
    }

    if (state.loadingUsage && usage.isEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(
              color: ramp.accent,
              strokeWidth: 2.4,
            ),
          ),
        ),
      );
      return sections;
    }

    if (usage.isEmpty) {
      sections.add(
        const EmptyHint(
          title: '这段时间还没有用量',
          detail: '电脑上的 QQA 处理过消息后才有统计；也确认控制台是 0.5 及以上',
        ),
      );
      return sections;
    }

    final totals = usage.totals;
    sections.add(
      GlassPanel(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: GlassMetric(
                    label: '总花费',
                    value: _money(totals.cost),
                    valueColor: ramp.accent,
                    hint: totals.runs > 0 ? '${totals.runs} 次调用' : null,
                  ),
                ),
                Expanded(
                  child: GlassMetric(
                    label: '总 token',
                    value: formatTokens(
                      totals.totalTokens,
                      scale: state.tokenScale,
                    ),
                    hint: totals.cachedTokens > 0
                        ? '缓存 ${formatTokens(totals.cachedTokens, scale: state.tokenScale)}'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GlassChip(
                  text:
                      '输入 ${formatTokens(totals.promptTokens, scale: state.tokenScale)}',
                  dense: true,
                  color: ramp.contentMuted,
                ),
                GlassChip(
                  text:
                      '输出 ${formatTokens(totals.completionTokens, scale: state.tokenScale)}',
                  dense: true,
                  color: ramp.contentMuted,
                ),
                GlassChip(
                  text: '缓存命中 ${_percent(totals.cacheHitRate)}',
                  dense: true,
                  color: GlassStatus.info,
                ),
                if (totals.searchCount > 0)
                  GlassChip(
                    text: '联网搜索 ${totals.searchCount} 次',
                    dense: true,
                    color: ramp.contentMuted,
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    final bars = usage.days.where((row) => !row.totals.isEmpty).toList();
    if (bars.isNotEmpty) {
      sections.add(const SizedBox(height: 16));
      sections.add(
        GlassSectionHeader(
          title: '按天',
          subtitle: '柱高按 token 计',
          trailing: GlassChip(text: '${bars.length} 天', dense: true),
        ),
      );
      sections.add(_DayBars(days: bars, scale: state.tokenScale));
    }

    final models = usage.topModels();
    if (models.isNotEmpty) {
      sections.add(const SizedBox(height: 16));
      sections.add(const GlassSectionHeader(title: '模型'));
      sections.add(
        _BucketCard(rows: models, scale: state.tokenScale, nameOf: _modelName),
      );
    }

    final chats = usage.topChats();
    if (chats.isNotEmpty) {
      sections.add(const SizedBox(height: 16));
      sections.add(const GlassSectionHeader(title: '花得最多的聊天'));
      sections.add(
        _BucketCard(rows: chats, scale: state.tokenScale, nameOf: _chatName),
      );
    }

    final tools = usage.toolCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (tools.isNotEmpty) {
      sections.add(const SizedBox(height: 16));
      sections.add(const GlassSectionHeader(title: '工具调用'));
      sections.add(
        GlassPanel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in tools.take(12))
                GlassChip(
                  text: '${entry.key} ×${entry.value}',
                  dense: true,
                  color: ramp.contentMuted,
                ),
            ],
          ),
        ),
      );
    }

    for (var index = 0; index < sections.length; index++) {
      sections[index] = StaggerIn(index: index, child: sections[index]);
    }
    return sections;
  }

  // ————————————————————————————— 日志 —————————————————————————————

  List<Widget> _logSections(AppState state) {
    final ramp = GlassScope.rampOf(context);
    final rows = state.logs;
    final sections = <Widget>[
      GlassSectionHeader(
        title: '运行日志',
        subtitle: '控制台最近打印的内容',
        trailing: GlassChip(text: '${rows.length} 条', dense: true),
      ),
      _RangeSwitch(
        ranges: [
          for (final level in logLevels) (wire: level.wire, label: level.label),
        ],
        selected: state.logLevel,
        onSelect: state.changeLogLevel,
      ),
      const SizedBox(height: 12),
    ];

    if (state.logsError != null) {
      sections.add(
        EmptyHint(
          title: '读取日志失败',
          detail: state.logsError,
          icon: Icons.cloud_off_rounded,
          onRetry: state.loadLogs,
        ),
      );
      return sections;
    }

    if (state.loadingLogs && rows.isEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(
              color: ramp.accent,
              strokeWidth: 2.4,
            ),
          ),
        ),
      );
      return sections;
    }

    if (rows.isEmpty) {
      sections.add(
        const EmptyHint(title: '没有日志', detail: '控制台升级到 0.5 后才会提供日志接口'),
      );
      return sections;
    }

    sections.add(
      GlassPanel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0)
                const GlassDivider(inset: 0)
              else
                const SizedBox(height: 4),
              _LogRow(entry: rows[index]),
            ],
          ],
        ),
      ),
    );
    return sections;
  }
}

/// 顶部两页切换（用量 / 日志）。
class _PageSwitch extends StatelessWidget {
  const _PageSwitch({required this.page, required this.onSelect});

  final int page;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    const labels = ['用量', '日志'];
    return GlassPanel(
      radius: GlassRadius.pill,
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(index),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.enter,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: index == page
                        ? ramp.accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(GlassRadius.pill),
                  ),
                  child: Center(
                    child: Text(
                      labels[index],
                      style: GlassText.label.copyWith(
                        color: index == page ? ramp.accent : ramp.contentMuted,
                        fontWeight: index == page
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 一排可选 chip（时间范围 / 日志级别共用）。
class _RangeSwitch extends StatelessWidget {
  const _RangeSwitch({
    required this.ranges,
    required this.selected,
    required this.onSelect,
  });

  final List<({String wire, String label})> ranges;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final range in ranges)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(range.wire),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GlassChip(
                text: range.label,
                color: range.wire == selected
                    ? GlassScope.rampOf(context).accent
                    : GlassScope.rampOf(context).contentMuted,
              ),
            ),
          ),
      ],
    );
  }
}

/// 按天柱状图：柱高按 token 归一化，柱是玻璃条 + 底部日期。
class _DayBars extends StatelessWidget {
  const _DayBars({required this.days, required this.scale});

  final List<UsageBucket> days;
  final TokenScale scale;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final peak = days
        .map((row) => row.totals.totalTokens)
        .fold<int>(1, (a, b) => b > a ? b : a);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: SizedBox(
        height: 108,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final day in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        formatTokensBare(day.totals.totalTokens, scale: scale),
                        style: GlassText.mono.copyWith(
                          color: ramp.contentFaint,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: FractionallySizedBox(
                          alignment: Alignment.bottomCenter,
                          heightFactor: (day.totals.totalTokens / peak).clamp(
                            0.04,
                            1.0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: ramp.accent.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _shortDay(day.label),
                        style: GlassText.caption.copyWith(
                          color: ramp.contentFaint,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 一组「名称 + token + 花费」的竖排行。
class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.rows,
    required this.scale,
    required this.nameOf,
  });

  final List<UsageBucket> rows;
  final TokenScale scale;
  final String Function(String) nameOf;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const GlassDivider(inset: 0),
            Row(
              children: [
                Expanded(
                  child: Text(
                    nameOf(rows[index].label),
                    style: GlassText.body.copyWith(color: ramp.content),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  formatTokens(rows[index].totals.totalTokens, scale: scale),
                  style: GlassText.mono.copyWith(color: ramp.contentMuted),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 58,
                  child: Text(
                    _money(rows[index].totals.cost),
                    textAlign: TextAlign.right,
                    style: GlassText.mono.copyWith(color: ramp.accent),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 一条日志：时间 + 级别 + 来源 + 正文。
class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final color = switch (entry.level) {
      'error' => GlassStatus.danger,
      'warn' => GlassStatus.warn,
      'debug' => ramp.contentFaint,
      _ => GlassStatus.info,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          child: Text(
            entry.clock,
            style: GlassText.mono.copyWith(
              color: ramp.contentFaint,
              fontSize: 10.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: GlassChip(text: entry.levelLabel, dense: true, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.source.isNotEmpty)
                Text(
                  entry.source,
                  style: GlassText.caption.copyWith(
                    color: ramp.contentFaint,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                entry.message,
                style: GlassText.body.copyWith(
                  color: entry.level == 'error'
                      ? GlassStatus.danger
                      : ramp.content,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `$0.42`（控制台给的是美元；0 就显示 `$0`）。
String _money(double value) {
  if (value <= 0) return r'$0';
  if (value < 0.01) return '\$${value.toStringAsFixed(4)}';
  return '\$${value.toStringAsFixed(2)}';
}

/// `85%`（控制台已给 0~1 或 0~100 都有，统一夹到 0~1）。
String _percent(double value) {
  final ratio = value > 1 ? value / 100 : value;
  return '${(ratio.clamp(0.0, 1.0) * 100).round()}%';
}

/// `2026-10-24` → `10/24`。
String _shortDay(String label) {
  final parts = label.split('-');
  if (parts.length == 3) return '${parts[1]}/${parts[2]}';
  return label;
}

/// `group:123` / `private:123` / `model` 名字转成人看得懂的样子。
String _chatName(String key) {
  if (key.startsWith('group:')) return '群聊 ${key.substring(6)}';
  if (key.startsWith('private:')) return '私聊 ${key.substring(8)}';
  return key.isEmpty ? '未知聊天' : key;
}

String _modelName(String key) => key.isEmpty ? '未知模型' : key;
