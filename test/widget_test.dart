import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:qqa_assistant/core/models.dart';

void main() {
  test('status payload maps the console contract', () {
    final status = StatusData.fromJson(const {
      'onebot': {'connected': true},
      'paused': false,
      'usage': {'calls': 12, 'totalTokens': 310000},
      'cacheHitRate': 0.85,
    });
    expect(status.connected, isTrue);
    expect(status.paused, isFalse);
    expect(status.calls, 12);
    expect(status.totalTokens, 310000);
    expect(status.cacheHitRate, closeTo(0.85, 1e-9));
  });

  test('status tolerates missing and malformed fields', () {
    final status = StatusData.fromJson(const {'usage': 'nope'});
    expect(status.connected, isFalse);
    expect(status.calls, 0);
    expect(status.cacheHitRate, 0);
  });

  test('rows are unwrapped from their envelope key', () {
    final rows = rowsFrom(const {
      'sessions': [
        {'id': 'a', 'status': 'running', 'sentCount': 3, 'triggerSummary': 'hi'},
      ],
    }, const ['sessions']);
    final row = SessionRow.fromJson(rows.single);
    expect(row.id, 'a');
    expect(row.status, 'running');
    expect(row.sentCount, 3);
    expect(row.trigger, 'hi');
  });

  test('rowsFrom accepts a bare list and ignores bad entries', () {
    final rows = rowsFrom([
      {'id': 'x'},
      'junk',
      {'id': 'y'},
    ], const ['sessions']);
    expect(rows.length, 2);
  });

  test('chat route key swaps the scope separator', () {
    const row = ChatRow(key: 'group:123');
    expect(row.routeKey, 'group_123');
  });

  test('messageText falls back across field names', () {
    expect(messageText(const {'text': 'hello'}), 'hello');
    expect(messageText(const {'content': 'draft'}), 'draft');
    expect(messageText(const {}), '');
  });

  test('dynamic library is reachable on this host', () {
    // Guards the asset name: the Rust core must be present as libqqa_core.so.
    expect(DynamicLibrary.open, isNotNull);
  });
}
