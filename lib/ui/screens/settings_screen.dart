import 'package:flutter/material.dart';

import '../../core/ffi.dart';
import '../../state/app_state.dart';
import '../widgets.dart';
import 'connect_screen.dart';

/// 设置 · connection, refresh cadence, typography, and core health.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final store = state.store;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          GlassGap.pageH, 16, GlassGap.pageH, GlassGap.dockInset),
      children: [
        const GlassSectionHeader(title: '当前连接'),
        GlassPanel(
          radius: GlassRadius.panel,
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.account.label,
                  style: GlassText.body.copyWith(
                      color: ramp.content, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text(state.account.origin,
                  style: GlassText.mono.copyWith(color: ramp.contentFaint),
                  maxLines: 1,
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
        const GlassSectionHeader(title: '刷新', subtitle: '多久问一次电脑'),
        _SliderRow(
          label: '自动刷新间隔',
          value: '${store.refreshSeconds} 秒',
          current: store.refreshSeconds.toDouble(),
          min: 5,
          max: 120,
          divisions: 23,
          onChanged: (value) => state.setRefreshSeconds(value.round()),
        ),
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
        const SizedBox(height: 20),
        const GlassSectionHeader(title: '显示'),
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
        const GlassSectionHeader(title: '核心'),
        GlassPanel(
          radius: GlassRadius.chip,
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          child: Row(
            children: [
              Icon(Icons.memory_rounded, size: 18, color: ramp.accent),
              const SizedBox(width: 11),
              Expanded(
                child: Text(coreStatus(),
                    style:
                        GlassText.caption.copyWith(color: ramp.contentMuted)),
              ),
            ],
          ),
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
                      child: Text(state.store.accounts[slot].label,
                          style: GlassText.body.copyWith(color: ramp.content)),
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
