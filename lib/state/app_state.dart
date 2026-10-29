import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api.dart';
import '../core/core.dart';
import '../core/models.dart';
import '../core/store.dart';
import '../core/tokens_fmt.dart';

/// Single source of truth for the whole app: the persisted store, the live API
/// client for the active account, and the last fetched snapshot.
class AppState extends ChangeNotifier {
  AppState(this.store) {
    _restartPolling();
    // 冷启动别干等第一个周期：地址是存下来的，直接拉一次。
    if (ready) Future.microtask(refreshAll);
  }

  final AppStore store;

  Account get account => store.active;

  StatusData status = const StatusData();
  String? statusError;
  DateTime? lastUpdated;
  bool loadingStatus = false;

  List<SessionRow> sessions = const [];
  List<String> sessionPreviews = const [];
  String? sessionsError;
  bool loadingSessions = false;

  List<ChatRow> chats = const [];
  String? chatsError;
  bool loadingChats = false;

  Timer? _statusTimer;
  Timer? _listTimer;
  bool _disposed = false;

  /// 每次换号/重连/断开都加一：在飞行中的请求回来时对不上就直接丢弃，
  /// 否则刚断开连接、上一轮的响应又把旧会话写回来了。
  int _epoch = 0;

  QqaApi? get api {
    final origin = account.origin;
    if (origin.isEmpty) return null;
    return QqaApi(origin);
  }

  bool get ready => account.configured;

  /// Seconds between automatic refreshes (user configurable).
  int get refreshSeconds => store.refreshSeconds;

  void _restartPolling() {
    _statusTimer?.cancel();
    _listTimer?.cancel();
    if (!ready) return;
    _statusTimer =
        Timer.periodic(Duration(seconds: refreshSeconds), (_) => refreshStatus());
    _listTimer = Timer.periodic(
        Duration(seconds: refreshSeconds * 2), (_) => refreshLists());
  }

  Future<void> refreshAll() async {
    await Future.wait([refreshStatus(), refreshLists()]);
  }

  /// 应用回到前台时调用：立刻补一次，不等下一个轮询周期。
  void resume() {
    if (!ready) return;
    _restartPolling();
    refreshAll();
  }

  Future<void> refreshStatus() async {
    final client = api;
    if (client == null || loadingStatus) return;
    final epoch = _epoch;
    loadingStatus = true;
    _notify();
    try {
      final snapshot = await client.status();
      if (epoch != _epoch) return;
      status = snapshot;
      statusError = null;
      lastUpdated = DateTime.now();
    } on Object catch (error) {
      if (epoch == _epoch) statusError = '$error';
    } finally {
      loadingStatus = false;
      _notify();
    }
  }

  Future<void> refreshLists() async {
    final client = api;
    if (client == null) return;
    final epoch = _epoch;
    if (!loadingSessions) {
      loadingSessions = true;
      _notify();
      try {
        final rows = await client.sessions(limit: store.sessionLimit);
        if (epoch != _epoch) return;
        // 预览由 Kotlin 内核一次折叠。会话与预览必须同时落定：中途 notify
        // 会让新行配上旧预览，出现「张冠李戴」的一行。
        List<String> collapsed;
        try {
          collapsed = await previews(rows.map((row) => row.trigger).toList());
        } on Object {
          collapsed = List<String>.filled(rows.length, '');
        }
        if (epoch != _epoch) return;
        sessions = rows;
        sessionPreviews = collapsed;
        sessionsError = null;
      } on Object catch (error) {
        if (epoch == _epoch) sessionsError = '$error';
      } finally {
        loadingSessions = false;
        _notify();
      }
    }
    if (!loadingChats) {
      loadingChats = true;
      _notify();
      try {
        final rows = await client.chats();
        if (epoch != _epoch) return;
        chats = rows;
        chatsError = null;
      } on Object catch (error) {
        if (epoch == _epoch) chatsError = '$error';
      } finally {
        loadingChats = false;
        _notify();
      }
    }
  }

  Future<List<MessageRow>> loadMessages(String chatKey) async {
    final client = api;
    if (client == null) return const [];
    return client.messages(chatKey, limit: store.messageLimit);
  }

  Future<Map<String, Object?>> loadSessionDetail(String id) async {
    final client = api;
    if (client == null) return const {};
    return client.sessionDetail(id);
  }

  Future<void> togglePaused() async {
    final client = api;
    if (client == null) return;
    final next = !status.paused;
    await client.setPaused(next);
    await refreshStatus();
  }

  /// Validate + persist a connection for [slot], then start polling.
  Future<void> connect(int slot, String typed, {String name = ''}) async {
    await store.connect(slot, typed, name: name);
    _epoch++;
    _restartPolling();
    _notify();
    await refreshAll();
  }

  /// 换号/断开共用的清场：数据、错误、时间戳一起清，在飞行中的响应作废。
  void _resetSnapshot() {
    _epoch++;
    status = const StatusData();
    sessions = const [];
    sessionPreviews = const [];
    chats = const [];
    statusError = null;
    sessionsError = null;
    chatsError = null;
    lastUpdated = null;
    loadingStatus = false;
    loadingSessions = false;
    loadingChats = false;
    _heroSignature = '';
  }

  Future<void> switchAccount(int slot) async {
    await store.setActiveSlot(slot);
    _resetSnapshot();
    _restartPolling();
    _notify();
    if (ready) await refreshAll();
  }

  Future<void> disconnectActive() async {
    await store.disconnect(account.slot);
    _resetSnapshot();
    _restartPolling();
    _notify();
  }

  Future<void> setRefreshSeconds(int value) async {
    await store.setRefreshSeconds(value);
    _restartPolling();
    _notify();
  }

  Future<void> setFontPercent(int value) async {
    await store.setFontPercent(value);
    _notify();
  }

  /// How token figures are scaled on the overview and logs tabs.
  TokenScale get tokenScale => store.tokenScale;

  Future<void> setTokenScale(TokenScale value) async {
    await store.setTokenScale(value);
    _notify();
  }

  /// One tap on a token figure walks auto → M → k → auto.
  Future<void> cycleTokenScale() async {
    await store.setTokenScale(store.tokenScale.next);
    _notify();
  }

  Future<void> setDarkMode(bool value) async {
    await store.setDarkMode(value);
    _notify();
  }

  Future<void> setQuickAccess(List<String> ids) async {
    await store.setQuickAccess(account.slot, ids);
    _notify();
  }

  /// Sessions that ended with a reply actually sent.
  ///
  /// Cannot use `sentCount > 0`: the console's list endpoint does not return a
  /// reply count, and the fallback (`usage.calls`) is the number of *model*
  /// calls, which is ≥1 for every session — that made this read 50/50.
  /// `status` is the honest signal (`done` vs `noreply` / `skipped`).
  int get repliedCount =>
      sessions.where((row) => row.status == 'done').length;

  /// Sessions the bot deliberately dropped (no reply / skipped).
  int get filteredCount => sessions
      .where((row) => row.status == 'noreply' || row.status == 'skipped')
      .length;

  /// Sessions still in flight — what the send queue is holding.
  int get runningCount =>
      sessions.where((row) => row.status == 'running').length;

  /// Labels the hero card and metric grid paint. Kotlin 算，这里只缓存：
  /// build 里必须同步拿到值，所以规则结果在 [_scheduleHero] 里异步刷新。
  Map<String, Object?> heroLabels() => _hero;

  /// Stand-in shown before the first Kotlin round trip lands — same text the
  /// rules would produce for a disconnected console, so nothing flickers.
  Map<String, Object?> _hero = const {
    'connectionLabel': '控制台未连接',
    'botLabel': 'DSH 未运行',
    'calls': '—',
    'totalTokens': '— tok',
    'hitRate': '—',
    'accent': 'idle',
  };

  String _heroSignature = '';
  bool _heroInFlight = false;

  /// 只在输入真的变了才过一次平台通道，避免每帧都问 Kotlin。
  void _scheduleHero() {
    final signature = '${status.connected}|${status.paused}|${status.calls}|'
        '${status.totalTokens}|${status.cacheHitRate}|${tokenScale.wire}';
    if (signature == _heroSignature || _heroInFlight) return;
    _heroSignature = signature;
    _heroInFlight = true;
    statusView({
      'connected': status.connected,
      'paused': status.paused,
      'calls': status.calls,
      'totalTokens': status.totalTokens,
      'cacheHitRate': status.cacheHitRate,
      'tokenUnit': tokenScale.wire,
    }).then((value) {
      _heroInFlight = false;
      if (_disposed) return;
      _hero = value;
      notifyListeners();
    }, onError: (Object _) {
      _heroInFlight = false;
      // 这次没算出来就把签名作废，下一次 notify 还会再试一次。
      _heroSignature = '';
    });
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
    _scheduleHero();
  }

  @override
  void dispose() {
    _disposed = true;
    _statusTimer?.cancel();
    _listTimer?.cancel();
    super.dispose();
  }
}
