// FFI bindings to the Rust core (`rust/src/lib.rs`).
//
// The Rust side owns *rules only*: address normalization and every label /
// number the UI prints. It stays pure-Rust (no C deps) so it cross-compiles to
// Android with nothing but the NDK clang present.
//
// Every entry point returns a UTF-8 C string holding
// `{"ok":true,"data":...}` or `{"ok":false,"error":"..."}`. This file decodes
// that envelope and frees the string, so callers only ever see Dart values.
//
// Each call is cheap, but they are still marshalled through `Isolate.run` when
// called from a screen's build path so nothing janks.

import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _Str1Native = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _Str1Dart = Pointer<Utf8> Function(Pointer<Utf8>);

typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

/// Thrown when the Rust core reports a failure.
class CoreException implements Exception {
  CoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _Bindings {
  _Bindings(DynamicLibrary lib)
      : version = lib.lookupFunction<_Str1Native, _Str1Dart>('qqa_version'),
        origin = lib.lookupFunction<_Str1Native, _Str1Dart>('qqa_origin'),
        describe = lib.lookupFunction<_Str1Native, _Str1Dart>('qqa_describe'),
        previews = lib.lookupFunction<_Str1Native, _Str1Dart>('qqa_previews'),
        statusView =
            lib.lookupFunction<_Str1Native, _Str1Dart>('qqa_status_view'),
        free = lib.lookupFunction<_FreeNative, _FreeDart>('qqa_string_free');

  final _Str1Dart version;
  final _Str1Dart origin;
  final _Str1Dart describe;
  final _Str1Dart previews;
  final _Str1Dart statusView;
  final _FreeDart free;
}

_Bindings? _cached;
String? _loadError;

/// Library file name differs per platform so the same code runs on the host
/// (useful for widget tests) and on a device.
String get _libraryName {
  if (const bool.fromEnvironment('dart.library.io')) {
    return 'libqqa_core.so';
  }
  return 'libqqa_core.so';
}

_Bindings get _bindings {
  final cached = _cached;
  if (cached != null) return cached;
  try {
    return _cached = _Bindings(DynamicLibrary.open(_libraryName));
  } on Object catch (error) {
    _loadError = '核心库加载失败：$error';
    rethrow;
  }
}

/// Non-throwing probe used by the settings screen to show core health.
String coreStatus() {
  try {
    final data = _decode(_call(_bindings.version, ''));
    return 'qqa_core ${(data as Map)['version']}';
  } on Object catch (error) {
    return _loadError ?? '$error';
  }
}

Object? _decode(Pointer<Utf8> raw) {
  if (raw == nullptr) {
    throw CoreException('核心库返回了空指针');
  }
  try {
    final decoded = jsonDecode(raw.toDartString());
    if (decoded is! Map) {
      throw CoreException('核心库返回了非对象数据');
    }
    if (decoded['ok'] != true) {
      throw CoreException((decoded['error'] as String?) ?? '未知错误');
    }
    return decoded['data'];
  } finally {
    _bindings.free(raw);
  }
}

/// Run one native call with a single string argument.
Pointer<Utf8> _call(_Str1Dart fn, String argument) {
  final arena = Arena();
  try {
    final pointer = argument.toNativeUtf8(allocator: arena);
    return fn(pointer);
  } finally {
    arena.releaseAll();
  }
}

Object? _invoke(_Str1Dart fn, String argument) => _decode(_call(fn, argument));

/// Normalize a user typed address into a bare `https://host[:port]`.
String normalizeOrigin(String input) {
  try {
    return _invoke(_bindings.origin, input) as String;
  } on CoreException {
    rethrow;
  }
}

/// Same as [normalizeOrigin] but returns null instead of throwing.
String? tryNormalizeOrigin(String input) {
  try {
    return normalizeOrigin(input);
  } on Object {
    return null;
  }
}

/// Format the presentation bundle for one snapshot.
Map<String, Object?> describe(Map<String, Object?> input) {
  final data = _invoke(_bindings.describe, jsonEncode(input));
  return (data as Map).cast<String, Object?>();
}

/// Collapse a batch of raw previews in one hop.
List<String> previews(List<String> items) {
  final data = _invoke(_bindings.previews, jsonEncode({'items': items}));
  return (data as List).map((row) => '$row').toList();
}

/// Connection label / metric strings for the overview hero card.
Map<String, Object?> statusView(Map<String, Object?> input) {
  final data = _invoke(_bindings.statusView, jsonEncode(input));
  return (data as Map).cast<String, Object?>();
}

/// Convenience wrapper so callers do not have to remember `Isolate.run`.
Future<T> offMain<T>(T Function() body) => Isolate.run(body);
