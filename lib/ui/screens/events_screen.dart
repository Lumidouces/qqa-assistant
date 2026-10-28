import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../widgets.dart';

/// 事件 · 消息存档（`/api/chats` + `/api/chats/{key}/messages`）。
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final rows = state.chats;
    return RefreshIndicator(
      color: QqaColors.accent,
      backgroundColor: QqaColors.surface,
      onRefresh: state.refreshLists,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
        children: [
          SectionHeader(
            title: '消息存档',
            trailing: Text('${rows.length} 个会话', style: QqaText.key),
          ),
          if (state.chatsError != null)
            EmptyHint(
              title: '读取存档失败',
              detail: state.chatsError,
              icon: Icons.cloud_off_rounded,
              onRetry: state.refreshLists,
            )
          else if (state.loadingChats && rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(
                    color: QqaColors.accent, strokeWidth: 2.4),
              ),
            )
          else if (rows.isEmpty)
            const EmptyHint(title: '还没有消息存档', detail: '电脑收到群聊或私聊消息后会出现在这里')
          else
            for (final row in rows)
              _ChatTile(state: state, row: row),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.state, required this.row});

  final AppState state;
  final ChatRow row;

  bool get _isGroup => row.isGroup;

  String get _title {
    if (row.title.trim().isNotEmpty) return row.title.trim();
    final raw = row.key.contains(':') ? row.key.split(':').last : row.key;
    return '${_isGroup ? '群' : '私聊'} ${raw.length > 10 ? '…${raw.substring(raw.length - 8)}' : raw}';
  }

  /// "刚刚 / 12 分钟前 / 10-27 21:30" — the raw ms epoch is unreadable on a phone.
  String get _when {
    final at = row.updatedAt;
    if (at == null) return '';
    final then = DateTime.fromMillisecondsSinceEpoch(at);
    final diff = DateTime.now().difference(then);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    final mm = then.month.toString().padLeft(2, '0');
    final dd = then.day.toString().padLeft(2, '0');
    final hh = then.hour.toString().padLeft(2, '0');
    final mi = then.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChatDetailScreen(state: state, row: row, title: _title),
        )),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: QqaDecor.card(radius: 16),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (_isGroup ? QqaColors.info : QqaColors.accent)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isGroup ? Icons.groups_rounded : Icons.person_rounded,
                  size: 19,
                  color: _isGroup ? QqaColors.info : QqaColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: QqaText.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      row.lastText.isEmpty ? row.key : row.lastText,
                      style: QqaText.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_when, style: QqaText.key),
                  const SizedBox(height: 4),
                  if (row.count > 0)
                    Chip2(
                        text: '${row.count}',
                        dense: true,
                        color: QqaColors.muted),
                ],
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: QqaColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

/// One chat's messages.
class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.state,
    required this.row,
    required this.title,
  });

  final AppState state;
  final ChatRow row;
  final String title;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  List<MessageRow> _messages = const [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final rows = await widget.state.loadMessages(widget.row.key);
      if (mounted) setState(() => _messages = rows);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: QqaColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: QqaText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(widget.row.key, style: QqaText.key, maxLines: 1),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: QqaColors.muted,
          ),
        ],
      ),
      body: _busy
          ? const Center(
              child: CircularProgressIndicator(
                  color: QqaColors.accent, strokeWidth: 2.4))
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyHint(title: '读取消息失败', detail: _error, onRetry: _load),
                )
              : _messages.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyHint(title: '这个会话还没有消息'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final row = _messages[index];
                        final mine = row.fromBot;
                        final who = row.senderName.trim();
                        final at = row.at;
                        final stamp = at == null
                            ? ''
                            : () {
                                final t =
                                    DateTime.fromMillisecondsSinceEpoch(at);
                                return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                              }();
                        return Align(
                          alignment:
                              mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.82,
                            ),
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: mine
                                  ? QqaColors.accent.withValues(alpha: 0.13)
                                  : QqaColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: mine
                                    ? QqaColors.accent.withValues(alpha: 0.3)
                                    : QqaColors.line,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: mine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                // In a group you cannot tell who is talking
                                // without this line.
                                if (!mine && who.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: Text(who, style: QqaText.key),
                                  ),
                                Text(
                                  row.text.isEmpty ? '（空消息）' : row.text,
                                  style: QqaText.body,
                                ),
                                if (stamp.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(stamp, style: QqaText.key),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
