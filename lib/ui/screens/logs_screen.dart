import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../widgets.dart';

/// 日志 · 会话过程（`/api/sessions`），点开看触发内容与已发送条目。
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final rows = state.sessions;
    final previews = state.sessionPreviews;

    return RefreshIndicator(
      color: QqaColors.accent,
      backgroundColor: QqaColors.surface,
      onRefresh: state.refreshLists,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
        children: [
          SectionHeader(
            title: '会话过程',
            trailing: Text('${rows.length} 条', style: QqaText.key),
          ),
          if (state.sessionsError != null)
            EmptyHint(
              title: '读取会话失败',
              detail: state.sessionsError,
              icon: Icons.cloud_off_rounded,
              onRetry: state.refreshLists,
            )
          else if (state.loadingSessions && rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(
                    color: QqaColors.accent, strokeWidth: 2.4),
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
        return (label: '进行中', color: QqaColors.accent);
      case 'waiting':
        return (label: '等待中', color: QqaColors.warn);
      case 'failed':
      case 'error':
        return (label: '失败', color: QqaColors.danger);
      case 'ended':
      case 'completed':
        return (label: '已结束', color: QqaColors.faint);
      default:
        return (
          label: row.status.isEmpty ? '已结束' : row.status,
          color: QqaColors.faint,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: QqaColors.surface,
          isScrollControlled: true,
          builder: (_) => _SessionSheet(state: state, row: row),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: QqaDecor.card(radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: status.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Chip2(text: status.label, color: status.color, dense: true),
                  const Spacer(),
                  Text('发送 ${row.sentCount}', style: QqaText.key),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                preview.isEmpty ? '（无触发内容）' : preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: QqaText.body,
              ),
              const SizedBox(height: 8),
              Text(row.id, style: QqaText.key, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail sheet: trigger text plus every `sent[]` entry.
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
  String? _error;

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

  @override
  Widget build(BuildContext context) {
    final sent = _detail['sent'];
    final messages = _detail['messages'];
    final trigger = '${_detail['triggerSummary'] ?? _detail['triggerText'] ?? _detail['trigger'] ?? ''}';
    final rounds = _detail['rounds'];
    final toolCalls = _detail['toolCalls'];
    final model = '${_detail['model'] ?? ''}';
    final error = '${_detail['errorHuman'] ?? _detail['error'] ?? ''}';
    final usage = _detail['usage'] is Map
        ? (_detail['usage'] as Map).cast<String, Object?>()
        : const <String, Object?>{};

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: QqaColors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('会话详情', style: QqaText.title),
          const SizedBox(height: 4),
          Text(widget.row.id, style: QqaText.key),
          const SizedBox(height: 14),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: CircularProgressIndicator(
                    color: QqaColors.accent, strokeWidth: 2.4),
              ),
            )
          else if (_error != null)
            EmptyHint(title: '读取失败', detail: _error)
          else ...[
            // Quick facts strip: these are what you actually look at when a
            // session went wrong, so they go above the long trigger text.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (rounds != null)
                  Chip2(text: '轮次 $rounds', dense: true, color: QqaColors.info),
                if (toolCalls != null)
                  Chip2(
                      text: '工具 $toolCalls',
                      dense: true,
                      color: QqaColors.info),
                if (model.isNotEmpty)
                  Chip2(text: model, dense: true, color: QqaColors.muted),
                if (usage['totalTokens'] != null)
                  Chip2(
                      text: '${usage['totalTokens']} tok',
                      dense: true,
                      color: QqaColors.muted),
              ],
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: QqaColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: QqaColors.danger.withValues(alpha: 0.35)),
                ),
                child: Text(error, style: QqaText.body),
              ),
            ],
            if (trigger.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionHeader(title: '触发'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: QqaDecor.card(radius: 14),
                child: Text(trigger, style: QqaText.body),
              ),
            ],
            // Real sessions usually have an empty `sent[]` and put the whole
            // conversation in `messages[]` (including tool calls), so show
            // whichever one actually has content.
            if (sent is List && sent.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionHeader(title: '已发送'),
              for (final item in sent.whereType<Map>())
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: QqaDecor.card(radius: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip2(
                        text: '${item['type'] ?? 'text'}',
                        dense: true,
                        color: QqaColors.info,
                      ),
                      const SizedBox(height: 8),
                      Text('${item['text'] ?? ''}', style: QqaText.body),
                    ],
                  ),
                ),
            ],
            if (messages is List && messages.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionHeader(
                title: '模型过程',
                trailing: Text('${messages.length} 条', style: QqaText.key),
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
    // The console records a finished turn as two shapes: a normal
    // `{role, content}` message, and a `{toolCall: {name, args, result}}`
    // entry with no role at all. Render both so a turn never shows up blank.
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
    final color = isTool ? QqaColors.muted : QqaColors.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: QqaDecor.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip2(text: role.isEmpty ? 'unknown' : role, dense: true, color: color),
              const Spacer(),
              if (names.isNotEmpty)
                Flexible(
                  child: Text(
                    names.join(', '),
                    style: QqaText.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(content, style: QqaText.body, maxLines: 12),
          ] else if (names.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('调用 ${names.join('、')}', style: QqaText.key),
          ],
        ],
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
    final name = '${call['name'] ?? 'tool'}';
    final isError = call['isError'] == true;
    final args = call['args'];
    final argText = args is Map && args.isNotEmpty
        ? args.entries.map((e) => '${e.key}=${e.value}').join('\n')
        : '';
    final result = '${call['result'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: QqaDecor.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip2(
                text: name,
                dense: true,
                color: isError ? QqaColors.danger : QqaColors.accent,
              ),
              const Spacer(),
              Text('工具调用', style: QqaText.key),
            ],
          ),
          if (argText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(argText, style: QqaText.key, maxLines: 6),
          ],
          if (result.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(result, style: QqaText.body, maxLines: 6),
          ],
        ],
      ),
    );
  }
}
