import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'version.dart';

/// Thrown for any failed `/api/` round trip, with a message that is safe to
/// show to the user (the original Java app used the same wording).
class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the QQA console on the PC.
///
/// The contract is deliberately narrow: every path must start with `/api/` and
/// may not walk upwards, so a bug (or a crafted server value) can never turn
/// this into a generic HTTP client.
class QqaApi {
  QqaApi(this.origin, {this.connectTimeout = const Duration(seconds: 10), this.readTimeout = const Duration(seconds: 15)});

  final String origin;
  final Duration connectTimeout;
  final Duration readTimeout;

  static final String _userAgent = 'QQA-Assistant/$appVersion (Flutter)';
  static const _maxBytes = 10 * 1024 * 1024;

  HttpClient _client() {
    final client = HttpClient()
      ..connectionTimeout = connectTimeout
      ..userAgent = _userAgent;
    return client;
  }

  String _url(String path, [Map<String, String>? query]) {
    if (!path.startsWith('/api/') || path.contains('..')) {
      throw ApiException('请求路径不合法');
    }
    final base = Uri.parse(origin);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
      queryParameters: query == null || query.isEmpty ? null : query,
    ).toString();
  }

  /// Shared request driver: maps every failure onto the app's Chinese copy.
  Future<Object?> _send(String method, String path,
      {Map<String, String>? query, Object? body}) async {
    final client = _client();
    try {
      final request = await client
          .openUrl(method, Uri.parse(_url(path, query)))
          .timeout(connectTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        final payload = utf8.encode(jsonEncode(body));
        request.headers.contentType = ContentType.json;
        request.headers.contentLength = payload.length;
        request.add(payload);
      }
      final response = await request.close().timeout(readTimeout);
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > _maxBytes) throw ApiException('电脑返回的数据过大');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw ApiException('服务未授权访问，请确认电脑上的 QQA 允许这台手机连接。');
      }
      if (response.statusCode == 502 || response.statusCode == 503) {
        throw ApiException('电脑上的 QQA 暂时没有运行，请启动后再试。');
      }
      if (response.statusCode == 404) {
        throw ApiException('电脑上的 QQA 没有这个接口，请把它升级到 0.5 或更高版本。');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('电脑暂时无法完成请求，请稍后重试。');
      }
      if (bytes.isEmpty) return const <String, Object?>{};
      return jsonDecode(utf8.decode(bytes));
    } on ApiException {
      rethrow;
    } on HandshakeException {
      throw ApiException('连接证书验证失败，请检查地址是否为可信任的 HTTPS。');
    } on SocketException {
      throw ApiException('连不上这个地址（域名解析失败或网络不通）。'
          '临时隧道地址会过期，到「设置 → 当前连接」换成最新地址再试。');
    } on TimeoutException {
      throw ApiException('电脑响应超时。地址可能已失效，或电脑端断网。');
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, Object?>> _getMap(String path,
      {Map<String, String>? query}) async {
    final body = await _send('GET', path, query: query);
    if (body is Map) return body.cast<String, Object?>();
    return const <String, Object?>{};
  }

  Future<StatusData> status() async =>
      StatusData.fromJson(await _getMap('/api/status'));

  Future<List<SessionRow>> sessions({int limit = 50}) async {
    final body = await _send('GET', '/api/sessions',
        query: {'limit': '$limit'});
    return rowsFrom(body, const ['sessions'])
        .map(SessionRow.fromJson)
        .toList();
  }

  Future<List<ChatRow>> chats() async {
    final body = await _send('GET', '/api/chats');
    return rowsFrom(body, const ['chats']).map(ChatRow.fromJson).toList();
  }

  Future<List<MessageRow>> messages(String chatKey, {int limit = 80}) async {
    final body = await _send(
      'GET',
      '/api/chats/${Uri.encodeComponent(chatKey.replaceAll(':', '_'))}/messages',
      query: {'limit': '$limit'},
    );
    return rowsFrom(body, const ['messages'])
        .map(MessageRow.fromJson)
        .toList();
  }

  /// `/api/sessions/{id}` returns the trigger plus everything that was sent.
  Future<Map<String, Object?>> sessionDetail(String id) =>
      _getMap('/api/sessions/${Uri.encodeComponent(id)}');

  Future<List<SkillRow>> skills() async {
    final body = await _send('GET', '/api/skills');
    return rowsFrom(body, const ['skills']).map(SkillRow.fromJson).toList();
  }

  Future<void> setPaused(bool paused) async {
    await _send('POST', '/api/pause', body: {'paused': paused});
  }

  /// `/api/usage/stats?range=1|7|30` — 0.5 起才有；0.4 会返回 404，由调用方
  /// 提示「控制台版本太旧」。
  Future<Map<String, Object?>> usageStats(String range) =>
      _getMap('/api/usage/stats', query: {'range': range});

  /// `/api/logs?limit=N` — 返回 `{logs: [...], level: 'info'}`。
  Future<Map<String, Object?>> recentLogs({int limit = 120}) =>
      _getMap('/api/logs', query: {'limit': '$limit'});

  /// `/api/logs/level` — 改控制台日志级别，body `{level}`。
  Future<void> setLogLevel(String level) async {
    await _send('POST', '/api/logs/level', body: {'level': level});
  }

  /// `/api/sessions/{id}/retry|abort` — 让卡住或失败的会话立刻重跑/中止。
  Future<void> sessionAction(String id, String action) async {
    if (action != 'retry' && action != 'abort') {
      throw ApiException('未知的会话操作');
    }
    await _send('POST',
        '/api/sessions/${Uri.encodeComponent(id)}/$action');
  }
}
