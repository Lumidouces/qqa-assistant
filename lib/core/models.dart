import 'dart:convert';

/// Tolerant readers. The real console and the local mock disagree on a few
/// field names (`runs` vs `calls`, `self` vs `role`, `total` vs `count`), so
/// every getter below tries both rather than betting on one shape.
int _asInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

Map<String, Object?> _asMap(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

String _firstString(List<Object?> values) {
  for (final value in values) {
    if (value is String && value.isNotEmpty) return value;
  }
  return '';
}

/// One `/api/status` snapshot.
class StatusData {
  const StatusData({
    this.connected = false,
    this.paused = false,
    this.calls = 0,
    this.totalTokens = 0,
    this.cacheHitRate = 0,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.cacheReadTokens = 0,
    this.model = '',
    this.onebot = '',
    this.cost = 0,
    this.botNickname = '',
    this.raw = const {},
  });

  final bool connected;
  final bool paused;
  final int calls;
  final int totalTokens;
  final double cacheHitRate;
  final int promptTokens;
  final int completionTokens;
  final int cacheReadTokens;
  final String model;
  final String onebot;
  final double cost;
  final String botNickname;
  final Map<String, Object?> raw;

  factory StatusData.fromJson(Map<String, Object?> json) {
    final onebot = _asMap(json['onebot']);
    final usage = _asMap(json['usage']);
    final orchestrator = _asMap(json['orchestrator']);
    final cost = _asMap(json['cost']);
    final self = _asMap(onebot['self']);

    return StatusData(
      connected: onebot['connected'] == true,
      paused: json['paused'] == true || orchestrator['paused'] == true,
      // Real console reports `runs`; the mock used `calls`.
      calls: _asInt(usage['runs'], _asInt(usage['calls'])),
      totalTokens: _asInt(usage['totalTokens']),
      cacheHitRate: _asDouble(json['cacheHitRate']),
      promptTokens: _asInt(usage['promptTokens']),
      completionTokens: _asInt(usage['completionTokens']),
      // `cachedTokens` on the real console, `cacheReadTokens` in the mock.
      cacheReadTokens:
          _asInt(usage['cachedTokens'], _asInt(usage['cacheReadTokens'])),
      // Model lives under orchestrator on the real console.
      model: _firstString([orchestrator['model'], json['model']]),
      onebot: _firstString([
        onebot['url'],
        onebot['endpoint'],
        json['onebotUrl'],
      ]),
      cost: _asDouble(cost['cost']),
      botNickname: _firstString([self['nickname'], self['userId']]),
      raw: json,
    );
  }
}

/// One row of `/api/sessions`.
class SessionRow {
  const SessionRow({
    required this.id,
    this.status = '',
    this.sentCount = 0,
    this.trigger = '',
    this.chatKey = '',
    this.rounds = 0,
    this.toolCalls = 0,
    this.activity = '',
    this.endedAt,
    this.startedAt,
  });

  final String id;
  final String status;
  final int sentCount;
  final String trigger;
  final String chatKey;
  final int rounds;
  final int toolCalls;
  final String activity;
  final int? endedAt;
  final int? startedAt;

  factory SessionRow.fromJson(Map<String, Object?> json) {
    final triggerNode = json['trigger'];
    final usage = _asMap(json['usage']);
    return SessionRow(
      id: '${json['id'] ?? ''}',
      status: '${json['status'] ?? ''}',
      // Real console keeps the reply count under usage.calls.
      sentCount: _asInt(json['sentCount'], _asInt(usage['calls'])),
      // Real console: `trigger` is a plain string on the list endpoint.
      // Older/mock shape: `triggerSummary` or `triggerText`.
      trigger: triggerNode is String
          ? triggerNode
          : _firstString([
              json['triggerSummary'],
              json['triggerText'],
            ]),
      chatKey: '${json['chatKey'] ?? ''}',
      rounds: _asInt(json['rounds']),
      toolCalls: _asInt(json['toolCalls']),
      activity: '${json['activity'] ?? ''}',
      endedAt: json['endedAt'] == null ? null : _asInt(json['endedAt']),
      startedAt: json['startedAt'] == null ? null : _asInt(json['startedAt']),
    );
  }
}

/// One row of `/api/chats`.
class ChatRow {
  const ChatRow({
    required this.key,
    this.title = '',
    this.count = 0,
    this.updatedAt,
    this.lastText = '',
    this.unread = 0,
  });

  final String key;
  final String title;
  final int count;
  final int? updatedAt;
  final String lastText;
  final int unread;

  /// `/api/chats/{key}` wants `:` swapped for `_`.
  String get routeKey => key.replaceAll(':', '_');

  bool get isGroup => key.startsWith('group:');

  factory ChatRow.fromJson(Map<String, Object?> json) {
    final key = _firstString([json['key'], json['chatKey'], json['id']]);
    return ChatRow(
      key: key,
      title: _firstString([
        json['chatName'],
        json['title'],
        json['name'],
        key.replaceFirst('group:', '群 ').replaceFirst('private:', '私聊 '),
      ]),
      // Real console: `total`; mock: `count`.
      count: _asInt(json['total'], _asInt(json['count'])),
      updatedAt: json['lastTs'] != null
          ? _asInt(json['lastTs'])
          : (json['updatedAt'] is num ? (json['updatedAt'] as num).toInt() : null),
      lastText: '${json['lastText'] ?? ''}',
      unread: _asInt(json['unread']),
    );
  }
}

/// One message inside a chat.
class MessageRow {
  const MessageRow({
    this.text = '',
    this.role = '',
    this.at,
    this.senderName = '',
    this.isSelf = false,
    this.summary = '',
  });

  final String text;
  final String role;
  final int? at;
  final String senderName;
  final bool isSelf;
  final String summary;

  bool get fromBot => isSelf || role == 'assistant' || role == 'bot';

  factory MessageRow.fromJson(Map<String, Object?> json) {
    // Real console marks the bot's own messages with `self: true` and gives no
    // `role`; the mock sends `role`. Honour whichever is present.
    final self = json['self'] == true;
    final role = _firstString([json['role'], json['sender']]);
    return MessageRow(
      text: messageText(json),
      role: role.isEmpty ? (self ? 'assistant' : 'user') : role,
      at: json['ts'] != null
          ? _asInt(json['ts'])
          : (json['at'] is num ? (json['at'] as num).toInt() : null),
      senderName: '${json['senderName'] ?? ''}',
      isSelf: self,
      summary: '${json['summary'] ?? ''}',
    );
  }
}

/// One `/api/skills` entry.
class SkillRow {
  const SkillRow({
    required this.id,
    this.name = '',
    this.loaded = false,
    this.enabled = false,
    this.views = const [],
    this.description = '',
    this.category = '',
  });

  final String id;
  final String name;
  final bool loaded;
  final bool enabled;
  final List<SkillViewRow> views;
  final String description;
  final String category;

  factory SkillRow.fromJson(Map<String, Object?> json) {
    final ui = _asMap(json['settingsUi']);
    final views = <SkillViewRow>[];
    if (ui['views'] is List) {
      for (final view in (ui['views'] as List).whereType<Map>()) {
        final map = view.cast<String, Object?>();
        views.add(SkillViewRow(
          id: '${map['id'] ?? ''}',
          title: '${map['title'] ?? ''}',
          file: '${map['file'] ?? ''}',
        ));
      }
    }
    return SkillRow(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      loaded: json['loaded'] == true,
      enabled: json['enabled'] == true,
      views: views,
      description: '${json['description'] ?? ''}',
      category: '${json['category'] ?? ''}',
    );
  }
}

/// A settings section a skill contributes.
class SkillViewRow {
  const SkillViewRow({this.id = '', this.title = '', this.file = ''});
  final String id;
  final String title;
  final String file;
}

/// Decode a JSON body that may be either a bare list or wrapped in a key.
List<Map<String, Object?>> rowsFrom(Object? body, List<String> keys) {
  Object? candidate = body;
  if (body is Map) {
    for (final key in keys) {
      if (body[key] is List) {
        candidate = body[key];
        break;
      }
    }
  }
  if (candidate is! List) return const [];
  return candidate
      .whereType<Map>()
      .map((row) => row.cast<String, Object?>())
      .toList();
}

/// Free-form text of a message row, whichever field it uses.
String messageText(Map<String, Object?> row) {
  for (final key in const ['text', 'content', 'body', 'message']) {
    final value = row[key];
    if (value is String && value.isNotEmpty) return value;
    if (value != null && value is! Map) return jsonEncode(value);
  }
  return '';
}
