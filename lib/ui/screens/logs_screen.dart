import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../state/app_state.dart';
import '../widgets.dart';
import '../../core/tokens_fmt.dart';

/// 过程 · `/api/sessions` — one glass row per session, tap for the full trace.
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final rows = state.sessions;
    final previews = state.sessionPreviews;

    return RefreshIndicator(
      color: ramp.accent,
      backgroundColor: ramp.page,
      onRefresh: state.refreshLists,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            GlassGap.pageH, 16, GlassGap.pageH, GlassGap.dockInset),
        children: [
          GlassSectionHeader(
            title: '会话过程',
            subtitle: '每次触发到回复的完整链路',
            trailing: GlassChip(text: '${rows.length} 条', dense: true),
          ),
          if (state.sessionsError != null)
            EmptyHint(
              title: '读取会话失败',
              detail: state.sessionsError,
              icon: Icons.cloud_off_rounded,
              onRetry: state.refreshLists,
            )
          else if (state.loadingSessions && rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 44),
              child: Center(
                child: CircularProgressIndicator(
                    color: ramp.accent, strokeWidth: 2.4),
              ),
            )
          else if (rows.isEmpty)
            const EmptyHint(title: '还没有会话记录', detail: '电脑上有消息进来后才会出现')
          else
            for (var index = 0; index < rows.length; index++)
              _SessionTile(
                row: rows[index],
                preview: index < previews.length ? previews[index] : '',
                state: state,
              ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.row,
    required this.preview,
    required this.state,
  });

  final SessionRow row;
  final String preview;
  final AppState state;

  ({String label, Color color}) get _status {
    switch (row.status) {
      case 'running':
        return (label: '进行中', color: GlassStatus.ok);
      case 'waiting':
        return (label: '等待中', color: GlassStatus.warn);
      case 'failed':
      case 'error':
        return (label: '失败', color: GlassStatus.danger);
      case 'noreply':
      case 'skipped':
        return (label: '未回复', color: GlassStatus.neutral);
      case 'done':
      case 'delivered':
        return (label: '已回复', color: GlassStatus.info);
      case 'ended':
      case 'completed':
        return (label: '已结束', color: GlassStatus.neutral);
      default:
        return (
          label: row.status.isEmpty ? '已结束' : row.status,
          color: GlassStatus.neutral,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final status = _status;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        radius: GlassRadius.panel,
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
        onTap: () => showGlassSheet<void>(
          context: context,
          builder: (_) => _SessionSheet(state: state, row: row),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GlassChip(text: status.label, dotColor: status.color, dense: true),
                const Spacer(),
                Text('发送 ${row.sentCount}',
                    style: GlassText.mono.copyWith(color: ramp.contentFaint)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              preview.isEmpty ? '（无触发内容）' : preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GlassText.body.copyWith(color: ramp.content),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.id,
                    style: GlassText.mono.copyWith(color: ramp.contentFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(stampTime(row.startedAt),
                    style: GlassText.mono.copyWith(color: ramp.contentFaint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail sheet: trigger text, quick facts, then the model trace.
class _SessionSheet extends StatefulWidget {
  const _SessionSheet({required this.state, required this.row});

  final AppState state;
  final SessionRow row;

  @override
  State<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<_SessionSheet> {
  Map<String, Object?> _detail = const {};
  bool _busy = true;
  bool _acting = false;
  String? _error;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.state.loadSessionDetail(widget.row.id);
      if (mounted) setState(() => _detail = detail);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// `retry` / `abort`：0.5 才有的会话处置接口。
  Future<void> _act(String action) async {
    if (_acting) return;
    setState(() {
      _acting = true;
      _actionError = null;
    });
    try {
      await widget.state.sessionAction(widget.row.id, action);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } on Object catch (error) {
      if (mounted) setState(() => _actionError = '$error');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final sent = _detail['sent'];
    final messages = _detail['messages'];
    final trigger =
        '${_detail['triggerSummary'] ?? _detail['triggerText'] ?? _detail['trigger'] ?? ''}';
    final rounds = _detail['rounds'];
    final toolCalls = _detail['toolCalls'];
    final model = '${_detail['model'] ?? ''}';
    final error = '${_detail['errorHuman'] ?? _detail['error'] ?? ''}';
    final usage = _detail['usage'] is Map
        ? (_detail['usage'] as Map).cast<String, Object?>()
        : const <String, Object?>{};
    final status = widget.row.status;
    final canAbort = status == 'running' || status == 'waiting';
    final canRetry = status == 'failed' ||
        status == 'error' ||
        status == 'noreply' ||
        status == 'skipped';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 30),
        children: [
          Text('会话详情', style: GlassText.title.copyWith(color: ramp.content)),
          const SizedBox(height: 4),
          Text(widget.row.id,
              style: GlassText.mono.copyWith(color: ramp.contentFaint)),
          const SizedBox(height: 14),
          if (_busy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: CircularProgressIndicator(
                    color: ramp.accent, strokeWidth: 2.4),
              ),
            )
          else if (_error != null)
            EmptyHint(title: '读取失败', detail: _error)
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (rounds != null)
                  GlassChip(
                      text: '轮次 $rounds',
                      dense: true,
                      color: GlassStatus.info),
                if (toolCalls != null)
                  GlassChip(
                      text: '工具 $toolCalls',
                      dense: true,
                      color: GlassStatus.info),
                if (model.isNotEmpty)
                  GlassChip(
                      text: model, dense: true, color: ramp.contentMuted),
                if (usage['totalTokens'] != null)
                  GlassChip(
                      text: formatTokens(
                          _tokenInt(usage['totalTokens']),
                          scale: widget.state.tokenScale),
                      dense: true,
                      color: ramp.contentMuted),
              ],
            ),
            if (canAbort || canRetry) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (canAbort)
                    Expanded(
                      child: GhostButton(
                        label: '中止这次',
                        icon: Icons.stop_circle_outlined,
                        onPressed: _acting ? null : () => _act('abort'),
                      ),
                    ),
                  if (canAbort && canRetry) const SizedBox(width: 10),
                  if (canRetry)
                    Expanded(
                      child: PrimaryButton(
                        label: '重试',
                        icon: Icons.refresh_rounded,
                        busy: _acting,
                        onPressed: _acting ? null : () => _act('retry'),
                      ),
                    ),
                ],
              ),
              if (_actionError != null) ...[
                const SizedBox(height: 8),
                Text(_actionError!,
                    style:
                        GlassText.caption.copyWith(color: GlassStatus.danger)),
              ],
            ],
            if (error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: GlassStatus.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(GlassRadius.chip),
                  border: Border.all(
                      color: GlassStatus.danger.withValues(alpha: 0.34)),
                ),
                child: Text(error,
                    style: GlassText.body.copyWith(color: GlassStatus.danger)),
              ),
            ],
            if (trigger.isNotEmpty) ...[
              const SizedBox(height: 16),
              const GlassSectionHeader(title: '触发'),
              GlassPanel(
                radius: GlassRadius.chip,
                padding: const EdgeInsets.all(14),
                tint: ramp.panelTint - 0.06,
                child: Text(trigger,
                    style: GlassText.body.copyWith(color: ramp.content)),
              ),
            ],
            // Real sessions usually ship an empty `sent[]` and keep the whole
            // conversation in `messages[]`, so render whichever has content.
            if (sent is List && sent.isNotEmpty) ...[
              const SizedBox(height: 16),
              const GlassSectionHeader(title: '已发送'),
              for (final item in sent.whereType<Map>())
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassPanel(
                    radius: GlassRadius.chip,
                    padding: const EdgeInsets.all(13),
                    tint: ramp.panelTint - 0.06,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlassChip(
                          text: '${item['type'] ?? 'text'}',
                          dense: true,
                          color: GlassStatus.info,
                        ),
                        const SizedBox(height: 9),
                        Text('${item['text'] ?? ''}',
                            style:
                                GlassText.body.copyWith(color: ramp.content)),
                      ],
                    ),
                  ),
                ),
            ],
            if (messages is List && messages.isNotEmpty) ...[
              const SizedBox(height: 16),
              GlassSectionHeader(
                title: '模型过程',
                trailing: GlassChip(
                    text: '${messages.length} 条', dense: true),
              ),
              for (final item in messages.whereType<Map>())
                _MessageBubble(item: item.cast<String, Object?>()),
            ],
          ],
        ],
      ),
    );
  }
}

/// One model turn: assistant text, the tools it called, or a tool result.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.item});

  final Map<String, Object?> item;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    // A finished turn is stored as either `{role, content}` or a bare
    // `{toolCall: {name, args, result}}`; render both so nothing shows blank.
    final toolCall = item['toolCall'];
    if (toolCall is Map) {
      return _ToolCallBubble(call: toolCall.cast<String, Object?>());
    }

    final role = '${item['role'] ?? ''}';
    final content = '${item['content'] ?? ''}';
    final calls = item['tool_calls'];
    final names = <String>[];
    if (calls is List) {
      for (final call in calls.whereType<Map>()) {
        final fn = call['function'];
        if (fn is Map && fn['name'] != null) names.add('${fn['name']}');
      }
    }
    final isTool = role == 'tool';
    final tint = isTool ? ramp.contentMuted : GlassStatus.info;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        radius: GlassRadius.chip,
        padding: const EdgeInsets.all(13),
        tint: ramp.panelTint - 0.06,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GlassChip(
                    text: role.isEmpty ? 'unknown' : role,
                    dense: true,
                    color: tint),
                const Spacer(),
                if (names.isNotEmpty)
                  Flexible(
                    child: Text(
                      names.join(', '),
                      style: GlassText.mono.copyWith(color: ramp.contentFaint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(content,
                  style: GlassText.body.copyWith(color: ramp.content),
                  maxLines: 14),
            ] else if (names.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text('调用 ${names.join('、')}',
                  style: GlassText.mono.copyWith(color: ramp.contentFaint)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One tool invocation as the console stores it: `{name, args, result}`.
class _ToolCallBubble extends StatelessWidget {
  const _ToolCallBubble({required this.call});

  final Map<String, Object?> call;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final name = '${call['name'] ?? 'tool'}';
    final isError = call['isError'] == true;
    final args = call['args'];
    final argText = args is Map && args.isNotEmpty
        ? args.entries.map((e) => '${e.key}=${e.value}').join('\n')
        : '';
    final result = '${call['result'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        radius: GlassRadius.chip,
        padding: const EdgeInsets.all(13),
        tint: ramp.panelTint - 0.02,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GlassChip(
                  text: name,
                  dense: true,
                  color: isError ? GlassStatus.danger : ramp.accent,
                ),
                const Spacer(),
                Text('工具调用',
                    style: GlassText.mono.copyWith(color: ramp.contentFaint)),
              ],
            ),
            if (argText.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(argText,
                  style: GlassText.mono.copyWith(color: ramp.contentMuted),
                  maxLines: 8),
            ],
            if (result.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(result,
                  style: GlassText.body.copyWith(color: ramp.content),
                  maxLines: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// `usage['totalTokens']` arrives as int, double or string depending on the
/// console build — normalise before formatting.
int _tokenInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? -1;
  return -1;
}
