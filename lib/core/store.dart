import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'core.dart';
import 'glass_quality.dart';
import 'tokens_fmt.dart';

/// One saved PC connection. The original app had two fixed slots ("账号1"));
/// keeping the same idea means switching PCs is one tap, exactly like before.
class Account {
  const Account({
    required this.slot,
    this.origin = '',
    this.name = '',
    this.quickAccess = const [],
  });

  final int slot;
  final String origin;
  final String name;

  /// Ordered tile ids shown in the "常用入口" grid.
  final List<String> quickAccess;

  bool get configured => origin.isNotEmpty;

  String get label {
    if (name.trim().isNotEmpty) return name.trim();
    if (origin.isEmpty) return '账号${slot + 1}';
    return origin.replaceFirst('https://', '');
  }

  Account copyWith({String? origin, String? name, List<String>? quickAccess}) {
    return Account(
      slot: slot,
      origin: origin ?? this.origin,
      name: name ?? this.name,
      quickAccess: quickAccess ?? this.quickAccess,
    );
  }

  Map<String, Object?> toJson() => {
        'origin': origin,
        'name': name,
        'quickAccess': quickAccess,
      };

  factory Account.fromJson(int slot, Object? json) {
    final map = json is Map ? json.cast<String, Object?>() : const {};
    final quick = map['quickAccess'];
    return Account(
      slot: slot,
      origin: '${map['origin'] ?? ''}',
      name: '${map['name'] ?? ''}',
      quickAccess: quick is List ? quick.map((e) => '$e').toList() : const [],
    );
  }
}

/// All locally persisted state: two account slots, which one is active, and the
/// per-account display preferences.
class AppStore {
  AppStore._(this._prefs);

  final SharedPreferences _prefs;

  static const _accountsKey = 'accounts';
  static const _activeKey = 'active_slot';
  static const _fontKey = 'font_percent';
  static const _darkKey = 'dark_mode';
  static const _limitKey = 'session_limit';
  static const _messageLimitKey = 'message_limit';
  static const _refreshKey = 'refresh_seconds';
  static const _tokenScaleKey = 'token_scale';
  static const _glassQualityKey = 'glass_quality';

  static const accountCount = 2;

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStore._(prefs);
  }

  List<Account> get accounts {
    final raw = _prefs.getString(_accountsKey);
    List<Account> parsed = const [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          parsed = [
            for (var index = 0; index < accountCount; index++)
              Account.fromJson(
                  index, index < decoded.length ? decoded[index] : null),
          ];
        }
      } on FormatException {
        parsed = const [];
      }
    }
    if (parsed.length < accountCount) {
      parsed = [
        for (var index = 0; index < accountCount; index++)
          index < parsed.length ? parsed[index] : Account(slot: index),
      ];
    }
    return parsed;
  }

  Account get active {
    final list = accounts;
    final index = activeSlot;
    return index >= 0 && index < list.length ? list[index] : list.first;
  }

  int get activeSlot {
    final value = _prefs.getInt(_activeKey) ?? 0;
    return value.clamp(0, accountCount - 1);
  }

  Future<void> saveAccount(Account account) async {
    final list = accounts.toList();
    list[account.slot] = account;
    await _prefs.setString(
        _accountsKey, jsonEncode(list.map((item) => item.toJson()).toList()));
  }

  Future<void> setActiveSlot(int slot) =>
      _prefs.setInt(_activeKey, slot.clamp(0, accountCount - 1));

  /// Validate then persist an origin typed by the user.
  Future<Account> connect(int slot, String typed, {String name = ''}) async {
    final normalized = await normalizeOrigin(typed);
    // 常用入口是跟着槽位走的偏好，重连/改地址不该把它清掉。
    final account = Account(
      slot: slot,
      origin: normalized,
      name: name,
      quickAccess: accounts[slot].quickAccess,
    );
    await saveAccount(account);
    await setActiveSlot(slot);
    return account;
  }

  Future<void> disconnect(int slot) async {
    final current = accounts[slot];
    // 断开只丢地址与备注以外的偏好：常用入口留着，重连后直接能用。
    await saveAccount(Account(
      slot: slot,
      name: current.name,
      quickAccess: current.quickAccess,
    ));
  }

  Future<void> setQuickAccess(int slot, List<String> ids) async {
    final current = accounts[slot];
    await saveAccount(current.copyWith(quickAccess: ids));
  }

  int get fontPercent => (_prefs.getInt(_fontKey) ?? 100).clamp(85, 160);
  Future<void> setFontPercent(int value) =>
      _prefs.setInt(_fontKey, value.clamp(85, 160));

  bool get darkMode => _prefs.getBool(_darkKey) ?? true;
  Future<void> setDarkMode(bool value) => _prefs.setBool(_darkKey, value);

  int get sessionLimit => (_prefs.getInt(_limitKey) ?? 50).clamp(5, 200);
  Future<void> setSessionLimit(int value) =>
      _prefs.setInt(_limitKey, value.clamp(5, 200));

  int get messageLimit => (_prefs.getInt(_messageLimitKey) ?? 80).clamp(10, 300);
  Future<void> setMessageLimit(int value) =>
      _prefs.setInt(_messageLimitKey, value.clamp(10, 300));

  /// How token figures are scaled — see `core/tokens_fmt.dart`.
  TokenScale get tokenScale {
    final raw = _prefs.getString(_tokenScaleKey) ?? 'auto';
    return TokenScale.values.firstWhere(
      (item) => item.wire == raw,
      orElse: () => TokenScale.auto,
    );
  }

  Future<void> setTokenScale(TokenScale value) =>
      _prefs.setString(_tokenScaleKey, value.wire);

  /// Glass render quality — mirrors SleepDown's `AppMaterialLevel`.
  GlassQuality get glassQuality =>
      GlassQuality.fromWire(_prefs.getString(_glassQualityKey));

  Future<void> setGlassQuality(GlassQuality value) =>
      _prefs.setString(_glassQualityKey, value.wire);

  int get refreshSeconds => (_prefs.getInt(_refreshKey) ?? 30).clamp(5, 300);
  Future<void> setRefreshSeconds(int value) =>
      _prefs.setInt(_refreshKey, value.clamp(5, 300));
}
