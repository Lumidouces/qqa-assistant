import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../core/tokens_fmt.dart';
import '../../core/version.dart';
import '../../state/app_state.dart';
import '../widgets.dart';
import '../../design/motion.dart';
import 'connect_screen.dart';

/// 设置页 —— 排版完全对齐 SleepDown-Schedule 的设置根页：
///
///   1. 顶部一个大的「设置」标题（上游 TopAppBar 的 largeTitle）；
///   2. 第一组是一张应用卡：56 圆角图标 + 应用名 + 右侧版本号；
///   3. 下面按「应用 / 连接 / 刷新 / 外观 / 其他」分组，每组上方一行
///      小号灰色分组标题，组内是 24 圆角卡片，行与行之间 1px 发丝线；
///   4. 每行结构固定：左侧 23dp 彩色图标 → 标题 + 副标题 → 右侧值 / 开关 / 箭头。
///
/// 数值与尺寸取自上游 `SettingsRootScreen.kt` 与 `SettingsRows.kt`。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final store = state.store;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          16, 8, 16, GlassGap.dockInset),
      children: [
        const _PageTitle('设置'),
        const SizedBox(height: 12),

        // ---- 应用卡 ----
        _Group(
          children: [
            _AppRow(
              version: appVersion,
              subtitle: 'Kotlin 规则内核 · Flutter 液态玻璃界面',
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ---- 应用 ----
        _SectionLabel('应用'),
        _Group(
          children: [
            _Row(
              icon: Icons.link_rounded,
              tint: const Color(0xFF0A84FF),
              title: '当前连接',
              subtitle: state.account.configured
                  ? state.account.origin
                  : '尚未配置控制台地址',
              trailing: _Value(
                  state.account.configured ? '已连接' : '未配置'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ConnectScreen(
                      state: state, slotOverride: state.account.slot),
                ),
              ),
            ),
            _Row(
              icon: Icons.swap_horiz_rounded,
              tint: const Color(0xFF34C759),
              title: '账号槽位',
              subtitle: '两个槽位各存一份地址，切换即时生效',
              trailing: _Value('槽位 ${store.activeSlot + 1}'),
              onTap: () => _showSlots(context),
            ),
            _Row(
              icon: Icons.link_off_rounded,
              tint: const Color(0xFFE5484D),
              title: '断开当前连接',
              subtitle: '只清掉这台手机上保存的地址，不影响服务器',
              danger: true,
              onTap: state.account.configured
                  ? () => state.disconnectActive()
                  : null,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ---- 刷新 ----
        _SectionLabel('刷新'),
        _Group(
          children: [
            _SliderRow(
              icon: Icons.timer_outlined,
              tint: const Color(0xFF5856D6),
              title: '自动刷新间隔',
              subtitle: '状态每 ${store.refreshSeconds} 秒拉一次，'
                  '列表每 ${store.refreshSeconds * 2} 秒拉一次',
              value: '${store.refreshSeconds} 秒',
              current: store.refreshSeconds.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              onChanged: (v) => state.setRefreshSeconds(v.round()),
            ),
            _SliderRow(
              icon: Icons.forum_outlined,
              tint: const Color(0xFF00A9C7),
              title: '会话列表条数',
              subtitle: '越大越慢，但看得更全',
              value: '${store.sessionLimit} 条',
              current: store.sessionLimit.toDouble(),
              min: 10,
              max: 200,
              divisions: 19,
              onChanged: (v) => store.setSessionLimit(v.round()),
            ),
            _SliderRow(
              icon: Icons.chat_bubble_outline_rounded,
              tint: const Color(0xFFAF52DE),
              title: '单会话消息条数',
              subtitle: '进入会话时最多取多少条',
              value: '${store.messageLimit} 条',
              current: store.messageLimit.toDouble(),
              min: 20,
              max: 300,
              divisions: 28,
              onChanged: (v) => store.setMessageLimit(v.round()),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ---- 外观 ----
        _SectionLabel('外观'),
        _Group(
          children: [
            _SwitchRow(
              icon: Icons.dark_mode_outlined,
              tint: const Color(0xFF0A84FF),
              title: '深色模式',
              subtitle: '深色下玻璃折射更明显，也更省电',
              value: store.darkMode,
              onChanged: state.setDarkMode,
            ),
            _SliderRow(
              icon: Icons.format_size_rounded,
              tint: const Color(0xFFFF9500),
              title: '字体大小',
              subtitle: '整体按比例缩放',
              value: '${store.fontPercent}%',
              current: store.fontPercent.toDouble(),
              min: 85,
              max: 160,
              divisions: 15,
              onChanged: (v) => state.setFontPercent(v.round()),
            ),
            _ChoiceRow(
              icon: Icons.straighten_rounded,
              tint: const Color(0xFF34C759),
              title: '数字单位',
              subtitle: '例：${formatTokens(13146300, scale: store.tokenScale)} · '
                  '${formatTokens(1314630000, scale: store.tokenScale)}',
              options: const [
                (TokenScale.auto, '自动'),
                (TokenScale.mega, 'M'),
                (TokenScale.kilo, 'k'),
              ],
              selected: store.tokenScale,
              onSelect: state.setTokenScale,
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ---- 其他 ----
        _SectionLabel('其他'),
        _Group(
          children: [
            _Row(
              icon: Icons.info_outline_rounded,
              tint: const Color(0xFF8A90A0),
              title: '版本信息',
              subtitle: '规则内核 ${_safeCore()}',
              trailing: _Value(appVersionFull),
              onTap: () => _showAbout(context),
            ),
            _Row(
              icon: Icons.favorite_rounded,
              tint: const Color(0xFFFF2D55),
              title: '致谢',
              subtitle: 'SleepDown-Schedule · Kyant Backdrop 2.0',
              onTap: () => _showCredits(context),
            ),
          ],
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

  Future<void> _showAbout(BuildContext context) async {
    final ramp = GlassScope.rampOf(context);
    final rows = <({String label, String value})>[
      (label: '应用版本', value: appVersionFull),
      (label: '规则内核', value: _safeCore()),
      (label: '界面', value: 'Flutter · Impeller'),
      (label: '玻璃材质', value: 'Kyant Backdrop 2.0 移植'),
      (label: '协议', value: 'HTTP · QQA 控制台'),
    ];
    await showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('版本信息',
              style: GlassText.title.copyWith(color: ramp.content)),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
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
    );
  }

  Future<void> _showCredits(BuildContext context) async {
    final ramp = GlassScope.rampOf(context);
    await showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('致谢',
              style: GlassText.title.copyWith(color: ramp.content)),
          const SizedBox(height: 8),
          Text(
            '界面风格与液态玻璃着色器移植自 SleepDown-Schedule'
            '（Kyant Backdrop 2.0，Apache-2.0）；规则内核为 Kotlin，界面为 Flutter。',
            style: GlassText.caption
                .copyWith(color: ramp.contentMuted, height: 1.55),
          ),
        ],
      ),
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
// 排版骨架（对齐 SettingsRootScreen.kt / SettingsGroups.kt）
// ---------------------------------------------------------------------------

/// 页面大标题：上游 `TopAppBar(largeTitle = ...)`，30sp 粗体、左对齐。
class _PageTitle extends StatelessWidget {
  const _PageTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
      child: Text(
        text,
        style: GlassText.display.copyWith(
          color: GlassScope.rampOf(context).content,
          fontSize: 30,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 分组标题：上游 `GlassPreferenceCategory`（MiuixSmallTitle），
/// 左侧 6、上下 8，灰色小字。
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      child: Text(
        text,
        style: GlassText.label.copyWith(
          color: GlassScope.rampOf(context).contentMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 分组卡片：上游 `SettingsGroup`，圆角 24，内部行不额外加间距。
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      // 每一行比上一行晚 40ms 淡入上移，分组卡整体像被「铺」出来。
      if (i > 0) {
        rows.add(StaggerIn(
          index: i,
          step: 40,
          offset: 8,
          child: Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Container(height: 1, color: ramp.hairline),
          ),
        ));
      }
      rows.add(StaggerIn(index: i, step: 40, offset: 8, child: children[i]));
    }

    return FadeSlideIn(
      offset: 10,
      child: GlassPanel(
        radius: GlassRadius.inner,
        padding: EdgeInsets.zero,
        tint: ramp.panelTint + 0.06,
        child: Column(children: rows),
      ),
    );
  }
}

/// 行尾的灰色数值。
class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GlassText.caption.copyWith(
        color: GlassScope.rampOf(context).contentFaint,
      ),
    );
  }
}

/// 基础行：23dp 彩色图标 + 标题/副标题 + 右侧内容。
/// 对应上游 `SettingsNavigationRow`（MiuixArrowPreference）。
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tint,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final enabled = onTap != null;
    final color = danger ? const Color(0xFFE5484D) : ramp.content;

    return Opacity(
      opacity: enabled || !danger ? 1 : 0.45,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GlassRadius.inner),
        splashColor: ramp.accent.withValues(alpha: 0.06),
        highlightColor: ramp.accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Icon(icon, size: 23, color: tint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GlassText.body.copyWith(
                        color: color,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GlassText.caption
                            .copyWith(color: ramp.contentFaint),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: trailing!,
                ),
              ],
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: ramp.contentFaint.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 开关行：上游 `Miuix SwitchPreference`。
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(GlassRadius.inner),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            Icon(icon, size: 23, color: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GlassText.body.copyWith(
                          color: ramp.content,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
              activeTrackColor: const Color(0xFF34C759),
              inactiveTrackColor: ramp.content.withValues(alpha: 0.12),
            ),
          ],
        ),
      ),
    );
  }
}

/// 滑杆行：上游设置里的 `SliderPreference`，数值用主题蓝显示在右侧。
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.value,
    required this.current,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
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
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 23, color: tint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GlassText.body.copyWith(
                            color: ramp.content,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GlassText.caption
                              .copyWith(color: ramp.contentFaint)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(value,
                  style: GlassText.caption.copyWith(
                      color: ramp.accent, fontWeight: FontWeight.w600)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: ramp.accent,
              inactiveTrackColor: ramp.hairline,
              thumbColor: Colors.white,
              overlayColor: ramp.accent.withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
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
    );
  }
}

/// 分段选择行：上游 `LiquidOptionTabs` 的紧凑版，右侧直接放胶囊选项。
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.subtitle,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Icon(icon, size: 23, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GlassText.body.copyWith(
                        color: ramp.content,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          GlassText.caption.copyWith(color: ramp.contentFaint)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(option.$1),
                child: AnimatedContainer(
                  duration: GlassMotion.fast,
                  curve: GlassMotion.curve,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected == option.$1
                        ? ramp.accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(GlassRadius.pill),
                    border: Border.all(
                      color: selected == option.$1
                          ? ramp.accent.withValues(alpha: 0.42)
                          : ramp.hairline,
                    ),
                  ),
                  child: Text(
                    option.$2,
                    style: GlassText.caption.copyWith(
                      color: selected == option.$1
                          ? ramp.accent
                          : ramp.contentMuted,
                      fontWeight: selected == option.$1
                          ? FontWeight.w700
                          : FontWeight.w500,
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

/// 应用卡：上游那个 56 圆角图标 + 应用名 + 版本号的行。
class _AppRow extends StatelessWidget {
  const _AppRow({required this.version, required this.subtitle});

  final String version;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(GlassRadius.inner),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ramp.accent, ramp.accentDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: ramp.accent.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 27, color: Colors.white),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('QQA 助手',
                      style: GlassText.title.copyWith(
                          color: ramp.content,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GlassText.caption
                          .copyWith(color: ramp.contentFaint)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('版本 $version',
                style: GlassText.caption.copyWith(color: ramp.contentMuted)),
          ],
        ),
      ),
    );
  }
}
