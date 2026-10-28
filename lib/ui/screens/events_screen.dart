import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../state/app_state.dart';
import '../widgets.dart';

/// 存档 · `/api/chats` — every conversation the bot has seen, newest first.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassScope.rampOf(context);
    final rows = state.chats;
    return RefreshIndicator(
      color: ramp.accent,
      backgroundColor: ramp.page,
      onRefresh: state.refreshLists,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            GlassGap.pageH, 16, GlassGap.pageH, GlassGap.dockInset),
        children: [
          GlassSectionHeader(
            title: '消息存档',
            subtitle: '群聊与私聊的完整消息记录',
            trailing: GlassChip(text: '${rows.length} 个', dense: true),
          ),
          if (state.chatsError != null)
            EmptyHint(
              title: '读取存档失败',
              detail: state.chatsError,
              icon: Icons.cloud_off_rounded,
              onRetry: state.refreshLists,
            )
          else if (state.loadingChats && rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 44),
              child: Center(
                child: CircularProgressIndicator(
                    color: ramp.accent, strokeWidth: 2.4),
              ),
            )
          else if (rows.isEmpty)
            const EmptyHint(title: '还没有消息存档', detail: '电脑收到群聊或私聊消息后会出现在这里')
          else
            for (final row in rows) _ChatTile(state: state, row: row),
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

  /// "刚刚 / 12 分钟前 / 10-27 21:30" — a raw ms epoch is unreadable on a phone.
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
    final ramp = GlassScope.rampOf(context);
    final tint = _isGroup ? GlassStatus.info : ramp.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        radius: GlassRadius.panel,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              ChatDetailScreen(state: state, row: row, title: _title),
        )),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(GlassRadius.chip),
                border: Border.all(color: tint.withValues(alpha: 0.22)),
              ),
              child: Icon(
                _isGroup ? Icons.groups_rounded : Icons.person_rounded,
                size: 19,
                color: tint,
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
                      style: GlassText.body.copyWith(
                          color: ramp.content, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    row.lastText.isEmpty ? row.key : row.lastText,
                    style: GlassText.caption.copyWith(color: ramp.contentFaint),
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
                Text(_when,
                    style: GlassText.mono.copyWith(color: ramp.contentFaint)),
                const SizedBox(height: 5),
                if (row.count > 0)
                  GlassChip(text: '${row.count}', dense: true),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 19, color: ramp.contentFaint),
          ],
        ),
      ),
    );
  }
}

/// One conversation's messages, opened from the archive list.
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
    final ramp = GlassScope.rampOf(context);
    final tone = GlassScope.of(context).tone;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded, size: 21, color: ramp.content),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: GlassText.title.copyWith(color: ramp.content),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(widget.row.key,
                style: GlassText.mono.copyWith(color: ramp.contentFaint),
                maxLines: 1),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded,
                size: 20, color: ramp.contentMuted),
          ),
        ],
      ),
      body: _busy
          ? Center(
              child: CircularProgressIndicator(
                  color: ramp.accent, strokeWidth: 2.4))
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyHint(
                      title: '读取消息失败', detail: _error, onRetry: _load),
                )
              : _messages.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: EmptyHint(title: '这个会话还没有消息'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final row = _messages[index];
                        return _Bubble(row: row, tone: tone);
                      },
                    ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.row, required this.tone});

  final MessageRow row;
  final GlassTone tone;

  @override
  Widget build(BuildContext context) {
    final ramp = GlassRamps.of(tone);
    final mine = row.fromBot;
    final who = row.senderName.trim();
    final at = row.at;
    final stamp = at == null
        ? ''
        : () {
            final t = DateTime.fromMillisecondsSinceEpoch(at);
            return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
          }();

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        decoration: BoxDecoration(
          color: mine
              ? ramp.accent.withValues(alpha: 0.14)
              : ramp.content.withValues(alpha: 0.05),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(GlassRadius.chip),
            topRight: const Radius.circular(GlassRadius.chip),
            bottomLeft: Radius.circular(mine ? GlassRadius.chip : 6),
            bottomRight: Radius.circular(mine ? 6 : GlassRadius.chip),
          ),
          border: Border.all(
            color: mine
                ? ramp.accent.withValues(alpha: 0.30)
                : ramp.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // In a group you cannot tell who is talking without this line.
            if (!mine && who.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(who,
                    style: GlassText.caption.copyWith(
                        color: ramp.accent, fontWeight: FontWeight.w600)),
              ),
            Text(
              row.text.isEmpty ? '（空消息）' : row.text,
              style: GlassText.body.copyWith(color: ramp.content),
            ),
            if (stamp.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(stamp,
                    style: GlassText.mono.copyWith(color: ramp.contentFaint)),
              ),
          ],
        ),
      ),
    );
  }
}
