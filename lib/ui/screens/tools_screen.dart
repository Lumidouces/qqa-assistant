import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../widgets.dart';

/// 操作 · 暂停/恢复自动回复，以及刷新、切换账号、断开。
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  bool _busy = false;

  AppState get state => widget.state;

  Future<void> _run(Future<void> Function() body) async {
    setState(() => _busy = true);
    try {
      await body();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final paused = state.status.paused;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          GlassGap.pageH, 16, GlassGap.pageH, GlassGap.dockInset),
      children: [
        const GlassSectionHeader(title: '自动回复', subtitle: '机器人的总开关'),
        GlassPanel(
          radius: GlassRadius.panel,
          padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
          tint: ramp.panelTint + 0.04,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusDot(
                    text: paused ? '已暂停' : '运行中',
                    color: paused ? GlassStatus.warn : ramp.accent,
                    fontSize: 13,
                  ),
                  const Spacer(),
                  GlassChip(text: state.account.label, dense: true),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                paused
                    ? '暂停后机器人仍在线，但不会自动回复任何消息。'
                    : '机器人会按规则自动回复电脑上收到的消息。',
                style: GlassText.caption.copyWith(color: ramp.contentMuted),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: paused ? '恢复自动回复' : '暂停自动回复',
                icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                busy: _busy,
                expand: true,
                onPressed: () => _run(state.togglePaused),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const GlassSectionHeader(title: '连接'),
        _ActionRow(
          icon: Icons.refresh_rounded,
          title: '立即刷新',
          detail: '重新拉取状态、会话与存档',
          onTap: () => _run(state.refreshAll),
        ),
        _ActionRow(
          icon: Icons.sync_alt_rounded,
          title: '切换账号',
          detail: '在账号 1 / 账号 2 之间切换',
          onTap: () => _showSwitchSheet(context),
        ),
        _ActionRow(
          icon: Icons.link_off_rounded,
          title: '断开连接',
          detail: '只清空本机保存的地址，不影响电脑',
          danger: true,
          onTap: () => _run(state.disconnectActive),
        ),
        const SizedBox(height: 20),
        const GlassSectionHeader(title: '关于'),
        GlassPanel(
          radius: GlassRadius.panel,
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QQA 助手 · Rust + Flutter 重写版',
                  style: GlassText.body.copyWith(
                      color: ramp.content, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('地址 ${state.account.origin}',
                  style: GlassText.mono.copyWith(color: ramp.contentFaint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                  '刷新间隔 ${state.refreshSeconds} 秒 · 会话 ${state.store.sessionLimit} 条',
                  style: GlassText.mono.copyWith(color: ramp.contentFaint)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showSwitchSheet(BuildContext context) async {
    final ramp = GlassScope.rampOf(context);
    final store = state.store;
    await showGlassSheet<void>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择账号',
              style: GlassText.title.copyWith(color: ramp.content)),
          const SizedBox(height: 16),
          for (var slot = 0; slot < 2; slot++)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: GlassPanel(
                radius: GlassRadius.chip,
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                tint: slot == store.activeSlot
                    ? ramp.panelTint + 0.08
                    : ramp.panelTint - 0.05,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _run(() => state.switchAccount(slot));
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.accounts[slot].label,
                              style: GlassText.body.copyWith(
                                  color: ramp.content,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(
                            store.accounts[slot].configured
                                ? store.accounts[slot].origin
                                : '未配置',
                            style: GlassText.mono
                                .copyWith(color: ramp.contentFaint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (slot == store.activeSlot)
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

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final color = danger ? GlassStatus.danger : ramp.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: GlassPanel(
        radius: GlassRadius.chip,
        padding: const EdgeInsets.fromLTRB(15, 14, 13, 14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GlassText.body.copyWith(
                          color: danger ? GlassStatus.danger : ramp.content,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(detail,
                      style:
                          GlassText.caption.copyWith(color: ramp.contentFaint)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 19, color: ramp.contentFaint),
          ],
        ),
      ),
    );
  }
}
