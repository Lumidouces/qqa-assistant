import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../widgets.dart';

/// First-run / reconnect screen: type the address of the PC console.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({
    super.key,
    required this.state,
    this.firstRun = false,
    this.slotOverride,
  });

  final AppState state;
  final bool firstRun;
  final int? slotOverride;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final TextEditingController _origin =
      TextEditingController(text: widget.state.account.origin);
  late final TextEditingController _name =
      TextEditingController(text: widget.state.account.name);
  int _slot = 0;
  bool _busy = false;
  String? _error;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _slot = widget.slotOverride ?? state.account.slot;
    final account = state.store.accounts[_slot];
    _origin.text = account.origin;
    _name.text = account.name;
  }

  @override
  void dispose() {
    _origin.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.connect(_slot, _origin.text, name: _name.text);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              GlassGap.pageH, 24, GlassGap.pageH, 34),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [ramp.accent, ramp.accentDeep],
                    ),
                    borderRadius: BorderRadius.circular(GlassRadius.chip),
                    boxShadow: [
                      BoxShadow(
                        color: ramp.accent.withValues(alpha: 0.32),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hub_rounded,
                      size: 21, color: Colors.white),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('连接你自己的 QQA',
                          style: GlassText.title.copyWith(
                              color: ramp.content, fontSize: 20)),
                      const SizedBox(height: 3),
                      Text('手机只做显示，机器人跑在电脑上',
                          style: GlassText.caption
                              .copyWith(color: ramp.contentFaint)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const GlassSectionHeader(title: '账号槽位'),
            Row(
              children: [
                for (var slot = 0; slot < 2; slot++) ...[
                  _SlotChip(
                    label: state.store.accounts[slot].label,
                    configured: state.store.accounts[slot].configured,
                    selected: _slot == slot,
                    onTap: () => setState(() {
                      _slot = slot;
                      final account = state.store.accounts[slot];
                      _origin.text = account.origin;
                      _name.text = account.name;
                    }),
                  ),
                  if (slot == 0) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 22),
            const GlassSectionHeader(title: '电脑地址'),
            TextField(
              controller: _origin,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: GlassText.body.copyWith(color: ramp.content),
              decoration: InputDecoration(
                hintText: 'https://your-tunnel.example.com',
                prefixIcon: Icon(Icons.link_rounded,
                    size: 18, color: ramp.contentFaint),
              ),
            ),
            const SizedBox(height: 9),
            Text('必须是 HTTPS 根地址，不要带路径、参数或 # 号。',
                style: GlassText.mono.copyWith(color: ramp.contentFaint)),
            const SizedBox(height: 18),
            const GlassSectionHeader(title: '备注名（可选）'),
            TextField(
              controller: _name,
              style: GlassText.body.copyWith(color: ramp.content),
              decoration: InputDecoration(
                hintText: '比如 家里主机',
                prefixIcon: Icon(Icons.badge_outlined,
                    size: 18, color: ramp.contentFaint),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: GlassStatus.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(GlassRadius.chip),
                  border: Border.all(
                      color: GlassStatus.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 17, color: GlassStatus.danger),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(_error!,
                          style: GlassText.caption.copyWith(
                              color: GlassStatus.danger)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: '连接并验证',
              icon: Icons.login_rounded,
              busy: _busy,
              expand: true,
              onPressed: _connect,
            ),
            const SizedBox(height: 10),
            if (!widget.firstRun)
              GhostButton(
                label: '取消',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            const SizedBox(height: 28),
            GlassPanel(
              radius: GlassRadius.panel,
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('连接方式',
                      style: GlassText.body.copyWith(
                          color: ramp.content, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _Step(index: 1, text: '电脑上启动 QQA 控制台'),
                  _Step(index: 2, text: '用隧道工具给它一个公网 HTTPS 地址'),
                  _Step(index: 3, text: '把隧道显示的 HTTPS 地址填到这里'),
                  const SizedBox(height: 4),
                  Text('地址只保存在本机，不会上传到任何服务器。',
                      style: GlassText.mono.copyWith(color: ramp.contentFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.configured,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool configured;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final tint = selected ? ramp.accent : ramp.contentFaint;

    return Expanded(
      child: GlassPanel(
        radius: GlassRadius.chip,
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        tint: selected ? ramp.panelTint + 0.08 : ramp.panelTint - 0.05,
        border: true,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GlassText.body.copyWith(
                color: selected ? ramp.accent : ramp.content,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(configured ? '已配置' : '未配置',
                style: GlassText.mono.copyWith(color: tint)),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 19,
            height: 19,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ramp.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Text('$index',
                style: GlassText.mono.copyWith(
                    color: ramp.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: GlassText.caption.copyWith(color: ramp.contentMuted))),
        ],
      ),
    );
  }
}
