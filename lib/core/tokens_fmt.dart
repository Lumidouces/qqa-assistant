/// Token counters, formatted the way people actually read them.
///
/// Mirrors `rust/src/rules.rs::token_count_in` so the phone and the core never
/// disagree about what `13146.3M` means.
///
/// Scale ladder:
///   < 1e3        → `512 tok`
///   ≥ 1e3        → `13.1k tok`
///   ≥ 1e6        → `13.1M tok`
///   ≥ 1e9        → `13.1B tok`
///
/// The user can pin a ceiling by tapping the figure:
///   [TokenScale.auto] → the ladder above (B wins once past a billion)
///   [TokenScale.mega] → never goes above M, so 13.1B reads back as 13146.3M
///   [TokenScale.kilo] → always k
enum TokenScale { auto, mega, kilo }

extension TokenScaleLabel on TokenScale {
  String get label => switch (this) {
        TokenScale.auto => '自动',
        TokenScale.mega => 'M',
        TokenScale.kilo => 'k',
      };

  /// What a tap moves to next.
  TokenScale get next => switch (this) {
        TokenScale.auto => TokenScale.mega,
        TokenScale.mega => TokenScale.kilo,
        TokenScale.kilo => TokenScale.auto,
      };

  String get wire => switch (this) {
        TokenScale.auto => 'auto',
        TokenScale.mega => 'm',
        TokenScale.kilo => 'k',
      };
}

/// Round half away from zero, then drop a trailing `.0` — same as the core.
String _oneDecimal(double value) {
  final rounded = (value * 10).round() / 10;
  final text = rounded.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// `13146300` → `13.1M tok`. Negative / unknown → `— tok`.
String formatTokens(int value, {TokenScale scale = TokenScale.auto}) {
  if (value < 0) return '— tok';
  final (divisor, suffix) = switch (scale) {
    // Below a thousand there is nothing to shorten — keep the raw count.
    TokenScale.kilo => value >= 1000 ? (1000.0, 'k') : (0.0, ''),
    TokenScale.mega => value >= 1000000
        ? (1000000.0, 'M')
        : value >= 1000
            ? (1000.0, 'k')
            : (0.0, ''),
    TokenScale.auto => value >= 1000000000
        ? (1000000000.0, 'B')
        : value >= 1000000
            ? (1000000.0, 'M')
            : value >= 1000
                ? (1000.0, 'k')
                : (0.0, ''),
  };
  if (divisor == 0) return '$value tok';
  return '${_oneDecimal(value / divisor)}$suffix tok';
}

/// Same number without the `tok` suffix — for chips where the unit is implied.
String formatTokensBare(int value, {TokenScale scale = TokenScale.auto}) {
  final text = formatTokens(value, scale: scale);
  return text.endsWith(' tok') ? text.substring(0, text.length - 4) : text;
}
