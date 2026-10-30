/// 0.5 控制台新增的两组只读接口：用量统计与运行日志。
///
/// 两个接口都只读、都可容忍字段缺失：控制台版本之间字段会变，缺字段时
/// 退回零值比抛异常更合适（页面上显示 0 总比整页报错强）。
library;

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _asString(Object? value) => value == null ? '' : '$value';

Map<String, Object?> _asMap(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const <String, Object?>{};

List<Map<String, Object?>> _asRows(Object? value) => value is List
    ? value.whereType<Map>().map((row) => row.cast<String, Object?>()).toList()
    : const <Map<String, Object?>>[];

/// 一组用量聚合值（总量 / 某一天 / 某个模型 / 某个聊天都用这一份）。
class UsageTotals {
  const UsageTotals({
    this.cost = 0,
    this.peakCost = 0,
    this.offPeakCost = 0,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.cachedTokens = 0,
    this.runs = 0,
    this.exactCalls = 0,
    this.cacheHitRate = 0,
    this.searchCount = 0,
  });

  final double cost;
  final double peakCost;
  final double offPeakCost;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int cachedTokens;
  final int runs;
  final int exactCalls;
  final double cacheHitRate;
  final int searchCount;

  factory UsageTotals.fromJson(Map<String, Object?> json) => UsageTotals(
        cost: _asDouble(json['cost']),
        peakCost: _asDouble(json['peakCost']),
        offPeakCost: _asDouble(json['offPeakCost']),
        promptTokens: _asInt(json['promptTokens']),
        completionTokens: _asInt(json['completionTokens']),
        totalTokens: _asInt(json['totalTokens']),
        cachedTokens: _asInt(json['cachedTokens']),
        runs: _asInt(json['runs']),
        exactCalls: _asInt(json['exactCalls']),
        cacheHitRate: _asDouble(json['cacheHitRate']),
        searchCount: _asInt(json['searchCount']),
      );

  bool get isEmpty =>
      totalTokens == 0 && runs == 0 && cost == 0 && exactCalls == 0;
}

/// 一条按天/按模型/按聊天拆开的用量行。
class UsageBucket {
  const UsageBucket({required this.label, required this.totals});

  final String label;
  final UsageTotals totals;

  factory UsageBucket.fromJson(Map<String, Object?> json) => UsageBucket(
        label: _asString(
          json['day'] ?? json['chatKey'] ?? json['model'] ?? json['label'],
        ),
        totals: UsageTotals.fromJson(json),
      );
}

/// `/api/usage/stats` 的整包结果。
class UsageStats {
  const UsageStats({
    this.range = '7',
    this.rangeLabel = '',
    this.totals = const UsageTotals(),
    this.days = const [],
    this.chats = const [],
    this.models = const [],
    this.toolCounts = const {},
    this.searchCount = 0,
  });

  final String range;
  final String rangeLabel;
  final UsageTotals totals;
  final List<UsageBucket> days;
  final List<UsageBucket> chats;
  final List<UsageBucket> models;
  final Map<String, int> toolCounts;
  final int searchCount;

  bool get isEmpty => totals.isEmpty && days.every((row) => row.totals.isEmpty);

  factory UsageStats.fromJson(Map<String, Object?> json) {
    final tools = _asMap(json['toolCounts']);
    return UsageStats(
      range: _asString(json['range']).isEmpty ? '7' : _asString(json['range']),
      rangeLabel: _asString(json['rangeLabel']),
      totals: UsageTotals.fromJson(_asMap(json['totals'])),
      days: _asRows(json['days']).map(UsageBucket.fromJson).toList(),
      chats: _asRows(json['chats']).map(UsageBucket.fromJson).toList(),
      models: _asRows(json['models']).map(UsageBucket.fromJson).toList(),
      toolCounts: {
        for (final entry in tools.entries) entry.key: _asInt(entry.value),
      },
      searchCount: _asInt(json['searchCount']),
    );
  }

  /// 花得最多的聊天，最多 [count] 条（控制台已按花费倒序返回）。
  List<UsageBucket> topChats([int count = 5]) =>
      chats.where((row) => !row.totals.isEmpty).take(count).toList();

  /// 用量最大的模型，最多 [count] 条。
  List<UsageBucket> topModels([int count = 5]) =>
      models.where((row) => !row.totals.isEmpty).take(count).toList();
}

/// `/api/logs` 的一条日志。
class LogEntry {
  const LogEntry({
    required this.at,
    required this.level,
    required this.source,
    required this.message,
  });

  final DateTime? at;
  final String level;
  final String source;
  final String message;

  factory LogEntry.fromJson(Map<String, Object?> json) => LogEntry(
        at: DateTime.tryParse(_asString(json['at'])),
        level: _asString(json['level']),
        source: _asString(json['src']),
        message: _asString(json['msg']),
      );

  /// 控制台日志级别 → 中文短标签。
  String get levelLabel => switch (level) {
        'debug' => '调试',
        'info' => '信息',
        'warn' => '警告',
        'error' => '错误',
        _ => level.isEmpty ? '日志' : level,
      };

  /// `06:12:33`，取本地时间；拿不到时间戳就返回空串。
  String get clock {
    final stamp = at?.toLocal();
    if (stamp == null) return '';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(stamp.hour)}:${two(stamp.minute)}:${two(stamp.second)}';
  }
}

/// 控制台支持的日志级别（顺序＝从详细到严重）。
const List<({String wire, String label})> logLevels = [
  (wire: 'debug', label: '调试'),
  (wire: 'info', label: '信息'),
  (wire: 'warn', label: '警告'),
  (wire: 'error', label: '错误'),
];
