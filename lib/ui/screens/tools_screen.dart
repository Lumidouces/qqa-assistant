import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
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
    final paused = state.status.paused;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
      children: [
        const SectionHeader(title: '自动回复'),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: QqaDecor.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusDot(
                    text: paused ? '已暂停' : '运行中',
                    color: paused ? QqaColors.warn : QqaColors.accent,
                    fontSize: 13,
                  ),
                  const Spacer(),
                  Text(state.account.label, style: QqaText.key),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                paused
                    ? '暂停后机器人仍在线，但不会自动回复任何消息。'
                    : '机器人会按规则自动回复电脑上收到的消息。',
                style: QqaText.muted,
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
        const SizedBox(height: 18),
        const SectionHeader(title: '连接'),
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
        const SizedBox(height: 18),
        const SectionHeader(title: '关于'),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: QqaDecor.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('QQA 助手 · Rust + Flutter 重写版', style: QqaText.body),
              const SizedBox(height: 6),
              Text('地址 ${state.account.origin}', style: QqaText.key),
              const SizedBox(height: 3),
              Text('刷新间隔 ${state.refreshSeconds} 秒 · 会话 ${state.store.sessionLimit} 条',
                  style: QqaText.key),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showSwitchSheet(BuildContext context) async {
    final store = state.store;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: QqaColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择账号', style: QqaText.title),
              const SizedBox(height: 14),
              for (var slot = 0; slot < 2; slot++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _run(() => state.switchAccount(slot));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: slot == store.activeSlot
                            ? QqaColors.accent.withValues(alpha: 0.1)
                            : QqaColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: slot == store.activeSlot
                              ? QqaColors.accent
                              : QqaColors.line,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(store.accounts[slot].label,
                                    style: QqaText.body
                                        .copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 3),
                                Text(
                                  store.accounts[slot].configured
                                      ? store.accounts[slot].origin
                                      : '未配置',
                                  style: QqaText.key,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          if (slot == store.activeSlot)
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: QqaColors.accent),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
    final color = danger ? QqaColors.danger : QqaColors.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: QqaDecor.card(radius: 14),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: QqaText.body.copyWith(
                            color: danger ? QqaColors.danger : QqaColors.text,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(detail, style: QqaText.muted),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 19, color: QqaColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
