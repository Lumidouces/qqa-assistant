import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme.dart';
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
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: QqaColors.heroGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.hub_rounded,
                      size: 21, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('连接你自己的 QQA',
                          style: TextStyle(
                              color: QqaColors.text,
                              fontSize: 19,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('手机只做显示，机器人跑在电脑上',
                          style: QqaText.muted),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const SectionHeader(title: '账号槽位'),
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
                  const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: '电脑地址'),
            TextField(
              controller: _origin,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'https://your-pc.tailnet.ts.net',
                prefixIcon: Icon(Icons.link_rounded,
                    size: 18, color: QqaColors.faint),
              ),
            ),
            const SizedBox(height: 8),
            const Text('必须是 HTTPS 根地址，不要带路径、参数或 # 号。',
                style: QqaText.key),
            const SizedBox(height: 18),
            const SectionHeader(title: '备注名（可选）'),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                hintText: '比如 家里主机',
                prefixIcon: Icon(Icons.badge_outlined,
                    size: 18, color: QqaColors.faint),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: QqaColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: QqaColors.danger.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 17, color: QqaColors.danger),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: QqaColors.danger, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            PrimaryButton(
              label: '连接并验证',
              icon: Icons.login_rounded,
              busy: _busy,
              expand: true,
              onPressed: _connect,
            ),
            const SizedBox(height: 12),
            if (!widget.firstRun)
              GhostButton(
                label: '取消',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: QqaDecor.card(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('连接方式', style: QqaText.title),
                  SizedBox(height: 10),
                  _Step(index: 1, text: '电脑上启动 QQA 与它的转接工具'),
                  _Step(index: 2, text: '两端都登录同一个 Tailscale 账号'),
                  _Step(index: 3, text: '把电脑显示的 HTTPS 地址填到这里'),
                  SizedBox(height: 6),
                  Text('地址只保存在本机，不会上传到任何服务器。',
                      style: QqaText.key),
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? QqaColors.accent.withValues(alpha: 0.12)
                : QqaColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? QqaColors.accent : QqaColors.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? QqaColors.accent : QqaColors.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(configured ? '已配置' : '未配置', style: QqaText.key),
            ],
          ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: QqaColors.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Text('$index',
                style: const TextStyle(
                    color: QqaColors.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: QqaText.muted)),
        ],
      ),
    );
  }
}
