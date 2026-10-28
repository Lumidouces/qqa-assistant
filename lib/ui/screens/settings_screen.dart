import 'package:flutter/material.dart';

import '../../core/ffi.dart';
import '../../state/app_state.dart';
import '../widgets.dart';
import 'connect_screen.dart';
import '../../core/tokens_fmt.dart';

/// 设置页 —— 对齐 SleepDown 的分段多标签结构：
///
///   1. 顶部是一张「软件介绍」卡（名称 / 版本 / 一句话 / 运行状态胶囊）；
///   2. 下面是液态玻璃胶囊标签栏（连接 · 刷新 · 外观 · 关于）；
///   3. 每个标签只放它自己的设置块，切页有淡入 + 轻微上浮动画。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _tabs = <({String label, IconData icon})>[
    (label: '连接', icon: Icons.link_rounded),
    (label: '刷新', icon: Icons.refresh_rounded),
    (label: '外观', icon: Icons.palette_rounded),
    (label: '关于', icon: Icons.info_rounded),
  ];

  int _index = 0;

  AppState get state => widget.state;

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          GlassGap.pageH, 12, GlassGap.pageH, GlassGap.dockInset),
      children: [
        _IntroCard(state: state),
        const SizedBox(height: GlassGap.lg),
        _TabBar(
          labels: [for (final tab in _tabs) tab.label],
          icons: [for (final tab in _tabs) tab.icon],
          index: _index,
          onSelect: _select,
        ),
        const SizedBox(height: GlassGap.lg),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey<int>(_index),
            child: switch (_index) {
              0 => _ConnectionTab(state: state),
              1 => _RefreshTab(state: state),
              2 => _AppearanceTab(state: state),
              _ => const _AboutTab(),
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 顶部：软件介绍
// ---------------------------------------------------------------------------

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final online = state.statusError == null && state.account.configured;

    return GlassPanel(
      radius: GlassRadius.panel,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ramp.accent,
                      ramp.accentDeep,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ramp.accent.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 23, color: Colors.white),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('QQA 助手',
                        style: GlassText.title.copyWith(
                          color: ramp.content,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 3),
                    Text('Rust 规则内核 · Flutter 液态玻璃界面',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            GlassText.caption.copyWith(color: ramp.contentFaint)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GlassChip(
                text: online ? '在线' : '未连接',
                dotColor: online ? const Color(0xFF30D158) : ramp.contentFaint,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '把服务器上跑的 QQA 控制台装进口袋：会话、过程、存档、一键操作都在这一屏里。',
            style: GlassText.caption.copyWith(
              color: ramp.contentMuted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              GlassChip(text: _versionLabel(), icon: Icons.memory_rounded, dense: true),
              GlassChip(text: 'v1.3.0', icon: Icons.sell_rounded, dense: true),
              GlassChip(
                text: state.account.configured
                    ? state.account.label
                    : '未配置地址',
                icon: Icons.dns_rounded,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _versionLabel() {
    try {
      return coreStatus();
    } catch (_) {
      return 'qqa_core 未加载';
    }
  }
}

// ---------------------------------------------------------------------------
// 分段标签栏
// ---------------------------------------------------------------------------

class _TabBar extends StatelessWidget {
  const _TabBar({
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
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: GlassMotion.base,
                  curve: GlassMotion.curve,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == index
                        ? ramp.accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(GlassRadius.pill),
                    border: Border.all(
                      color: i == index
                          ? ramp.accent.withValues(alpha: 0.42)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icons[i],
                        size: 15,
                        color: i == index ? ramp.accent : ramp.contentMuted,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GlassText.label.copyWith(
                            color:
                                i == index ? ramp.accent : ramp.contentMuted,
                            fontWeight: i == index
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 标签页内容
// ---------------------------------------------------------------------------

class _ConnectionTab extends StatelessWidget {
  const _ConnectionTab({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final store = state.store;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlassSectionHeader(title: '当前连接', subtitle: '这台手机连的是哪台机器'),
        GlassPanel(
          radius: GlassRadius.panel,
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(state.account.label,
                        style: GlassText.body.copyWith(
                            color: ramp.content,
                            fontWeight: FontWeight.w600)),
                  ),
                  GlassChip(
                    text: '槽位 ${store.activeSlot + 1}',
                    dense: true,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(state.account.origin,
                  style: GlassText.mono.copyWith(color: ramp.contentFaint),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: '更换地址',
                      icon: Icons.edit_rounded,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ConnectScreen(
                              state: state, slotOverride: state.account.slot),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GhostButton(
                      label: '账号槽位',
                      icon: Icons.sync_alt_rounded,
                      onPressed: () => _showSlots(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const GlassSectionHeader(title: '会话', subtitle: '断开后需要重新填地址'),
        _DangerRow(
          title: '断开当前连接',
          subtitle: '只清掉这台手机上保存的地址，不影响服务器',
          icon: Icons.link_off_rounded,
          onTap: state.account.configured ? state.disconnectActive : null,
        ),
      ],
    );
  }

  Future<void> _showSlots(BuildContext context) async {
    final ramp = GlassScope.rampOf(context);
    await showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('账号槽位',
              style: GlassText.title.copyWith(color: ramp.content)),
          const SizedBox(height: 6),
          Text('两个槽位各存一份地址，切换即时生效',
              style: GlassText.caption.copyWith(color: ramp.contentFaint)),
          const SizedBox(height: 16),
          for (var slot = 0; slot < 2; slot++)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: GlassPanel(
                radius: GlassRadius.chip,
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                tint: slot == state.store.activeSlot
                    ? ramp.panelTint + 0.08
                    : ramp.panelTint - 0.05,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  state.switchAccount(slot);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.store.accounts[slot].label,
                              style: GlassText.body
                                  .copyWith(color: ramp.content)),
                          const SizedBox(height: 2),
                          Text(
                            state.store.accounts[slot].configured
                                ? state.store.accounts[slot].origin
                                : '未配置',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GlassText.mono
                                .copyWith(color: ramp.contentFaint),
                          ),
                        ],
                      ),
                    ),
                    if (slot == state.store.activeSlot)
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: ramp.accent),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RefreshTab extends StatelessWidget {
  const _RefreshTab({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final store = state.store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlassSectionHeader(title: '轮询节奏', subtitle: '多久问一次电脑'),
        _SliderRow(
          label: '自动刷新间隔',
          value: '${store.refreshSeconds} 秒',
          current: store.refreshSeconds.toDouble(),
          min: 5,
          max: 120,
          divisions: 23,
          onChanged: (value) => state.setRefreshSeconds(value.round()),
        ),
        const SizedBox(height: 20),
        const GlassSectionHeader(title: '拉取数量', subtitle: '越大越慢，但看得更全'),
        _SliderRow(
          label: '会话列表条数',
          value: '${store.sessionLimit} 条',
          current: store.sessionLimit.toDouble(),
          min: 10,
          max: 200,
          divisions: 19,
          onChanged: (value) => store.setSessionLimit(value.round()),
        ),
        _SliderRow(
          label: '单会话消息条数',
          value: '${store.messageLimit} 条',
          current: store.messageLimit.toDouble(),
          min: 20,
          max: 300,
          divisions: 28,
          onChanged: (value) => store.setMessageLimit(value.round()),
        ),
        const SizedBox(height: 16),
        GlassPanel(
          radius: GlassRadius.chip,
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 17, color: GlassScope.rampOf(context).accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '状态每 ${store.refreshSeconds} 秒拉一次，列表每 ${store.refreshSeconds * 2} 秒拉一次。',
                  style: GlassText.caption.copyWith(
                      color: GlassScope.rampOf(context).contentMuted,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final store = state.store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlassSectionHeader(title: '主题', subtitle: '液态玻璃的明暗底'),
        SettingSwitch(
          title: '深色模式',
          subtitle: '深色下玻璃折射更明显，也更省电',
          value: store.darkMode,
          onChanged: state.setDarkMode,
        ),
        const SizedBox(height: 20),
        const GlassSectionHeader(title: '排版'),
        _SliderRow(
          label: '字体大小',
          value: '${store.fontPercent}%',
          current: store.fontPercent.toDouble(),
          min: 85,
          max: 160,
          divisions: 15,
          onChanged: (value) => state.setFontPercent(value.round()),
        ),
        const SizedBox(height: 20),
        const GlassSectionHeader(title: '数字单位', subtitle: '大数字怎么缩写'),
        Row(
          children: [
            for (final scale in TokenScale.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => state.setTokenScale(scale),
                  behavior: HitTestBehavior.opaque,
                  child: GlassChip(
                    text: switch (scale) {
                      TokenScale.auto => '自动（M / B）',
                      TokenScale.mega => '固定 M',
                      TokenScale.kilo => '固定 k',
                    },
                    dense: true,
                    color: store.tokenScale == scale
                        ? GlassScope.rampOf(context).accent
                        : GlassScope.rampOf(context).contentMuted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '例：${formatTokens(13146300, scale: store.tokenScale)} · '
          '${formatTokens(1314630000, scale: store.tokenScale)}',
          style: GlassText.mono
              .copyWith(color: GlassScope.rampOf(context).contentFaint),
        ),
      ],
    );
  }
}

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final rows = <({String label, String value})>[
      (label: '应用版本', value: '1.3.0 (build 3)'),
      (label: '规则内核', value: _safeCore()),
      (label: '界面', value: 'Flutter 3.35 · Impeller'),
      (label: '玻璃材质', value: 'Kyant Backdrop 2.0 移植'),
      (label: '协议', value: 'HTTP · QQA 控制台'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GlassSectionHeader(title: '版本信息'),
        GlassPanel(
          radius: GlassRadius.panel,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) GlassDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(rows[i].label,
                            style: GlassText.body
                                .copyWith(color: ramp.contentMuted)),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          rows[i].value,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GlassText.mono.copyWith(color: ramp.content),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const GlassSectionHeader(title: '致谢'),
        GlassPanel(
          radius: GlassRadius.chip,
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          child: Text(
            '界面风格与液态玻璃着色器移植自 SleepDown-Schedule（Kyant Backdrop 2.0，Apache-2.0）；'
            '规则内核为 Rust，UI 为 Flutter。',
            style: GlassText.caption
                .copyWith(color: ramp.contentMuted, height: 1.55),
          ),
        ),
      ],
    );
  }

  static String _safeCore() {
    try {
      return coreStatus();
    } catch (_) {
      return '未加载';
    }
  }
}

// ---------------------------------------------------------------------------
// 行组件
// ---------------------------------------------------------------------------

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final enabled = onTap != null;
    const danger = Color(0xFFE5484D);

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GlassPanel(
        radius: GlassRadius.chip,
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 18, color: danger),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GlassText.body.copyWith(
                          color: danger, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style:
                          GlassText.caption.copyWith(color: ramp.contentFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.current,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String value;
  final double current;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassPanel(
        radius: GlassRadius.chip,
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(label,
                        style: GlassText.body.copyWith(color: ramp.content))),
                Text(value,
                    style: GlassText.mono.copyWith(color: ramp.contentFaint)),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: ramp.accent,
                inactiveTrackColor: ramp.hairline,
                thumbColor: ramp.accent,
                overlayColor: ramp.accent.withValues(alpha: 0.12),
                trackHeight: 3,
              ),
              child: Slider(
                value: current.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
