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

  Future<void> refreshStatus() async {
    final client = api;
    if (client == null || loadingStatus) return;
    loadingStatus = true;
    _notify();
    try {
      status = await client.status();
      statusError = null;
      lastUpdated = DateTime.now();
    } on Object catch (error) {
      statusError = '$error';
    } finally {
      loadingStatus = false;
      _notify();
    }
  }

  Future<void> refreshLists() async {
    final client = api;
    if (client == null) return;
    if (!loadingSessions) {
      loadingSessions = true;
      _notify();
      try {
        final rows = await client.sessions(limit: store.sessionLimit);
        sessions = rows;
        sessionsError = null;
        // Previews are collapsed by the Rust core in one FFI hop.
        sessionPreviews =
            await previews(rows.map((row) => row.trigger).toList());
      } on Object catch (error) {
        sessionsError = '$error';
      } finally {
        loadingSessions = false;
        _notify();
      }
    }
    if (!loadingChats) {
      loadingChats = true;
      _notify();
      try {
        chats = await client.chats();
        chatsError = null;
      } on Object catch (error) {
        chatsError = '$error';
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
    _restartPolling();
    _notify();
    await refreshAll();
  }

  Future<void> switchAccount(int slot) async {
    await store.setActiveSlot(slot);
    status = const StatusData();
    sessions = const [];
    chats = const [];
    sessionPreviews = const [];
    statusError = null;
    _restartPolling();
    _notify();
    if (ready) await refreshAll();
  }

  Future<void> disconnectActive() async {
    await store.disconnect(account.slot);
    status = const StatusData();
    sessions = const [];
    chats = const [];
    sessionPreviews = const [];
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
