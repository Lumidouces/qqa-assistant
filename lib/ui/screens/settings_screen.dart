import 'package:flutter/material.dart';

import '../../core/ffi.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../widgets.dart';
import 'connect_screen.dart';

/// 设置 · connection, refresh cadence, typography, and core health.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final store = state.store;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
      children: [
        const SectionHeader(title: '当前连接'),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: QqaDecor.card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.account.label, style: QqaText.title),
              const SizedBox(height: 4),
              Text(state.account.origin, style: QqaText.key, maxLines: 1),
              const SizedBox(height: 12),
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
        const SizedBox(height: 18),
        const SectionHeader(title: '刷新'),
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
        const SizedBox(height: 18),
        const SectionHeader(title: '显示'),
        _SliderRow(
          label: '字体大小',
          value: '${store.fontPercent}%',
          current: store.fontPercent.toDouble(),
          min: 85,
          max: 160,
          divisions: 15,
          onChanged: (value) => state.setFontPercent(value.round()),
        ),
        const SizedBox(height: 18),
        const SectionHeader(title: '核心'),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: QqaDecor.card(),
          child: Row(
            children: [
              const Icon(Icons.memory_rounded, size: 18, color: QqaColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(coreStatus(), style: QqaText.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showSlots(BuildContext context) async {
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
              const Text('账号槽位', style: QqaText.title),
              const SizedBox(height: 14),
              for (var slot = 0; slot < 2; slot++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      state.switchAccount(slot);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: slot == state.store.activeSlot
                            ? QqaColors.accent.withValues(alpha: 0.1)
                            : QqaColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: slot == state.store.activeSlot
                                ? QqaColors.accent
                                : QqaColors.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(state.store.accounts[slot].label,
                                style: QqaText.body),
                          ),
                          if (slot == state.store.activeSlot)
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
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
      decoration: QqaDecor.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: QqaText.body)),
              Text(value, style: QqaText.muted),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: QqaColors.accent,
              inactiveTrackColor: QqaColors.line,
              thumbColor: QqaColors.accent,
              overlayColor: QqaColors.accent.withValues(alpha: 0.12),
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
    );
  }
}
