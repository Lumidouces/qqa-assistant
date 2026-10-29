// Dart 侧规则内核入口 —— 两种后端，同一套 API。
//
// 仓库里有两个语义完全等价的规则内核，编译期二选一：
//
//   * Kotlin（`android/app/src/main/kotlin/.../QqaCore.kt`）——默认，
//     经 MethodChannel `qqa/core` 调用，产物是 dex，不需要 NDK。
//   * Rust（`rust/` 的 `qqa_core`）——经 `dart:ffi` 直调 `libqqa_core.so`，
//     同步、无通道往返，代价是每个 ABI 都要带一份 .so。
//
// 选择方式：
//
//   flutter build apk --release --target-platform android-arm64 \
//     --dart-define=QQA_KERNEL_RUST=true
//
// 不传就是 Kotlin 版。App 代码只认这一层的 API，所以换后端不需要改任何界面代码。
//
// 规则函数都是纯函数且极便宜。Rust 后端是同步调用（微秒级），这里仍然统一返回
// Future，保证调用点写法与 Kotlin 后端一致；Kotlin 后端本身异步，热点路径
// （概览大卡）由 `AppState.heroLabels` 缓存住，不在 build 里等通道。

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

/// 编译期开关；不传 `--dart-define=QQA_KERNEL_RUST=true` 就是 false。
const bool kRustKernel = bool.fromEnvironment('QQA_KERNEL_RUST');

/// 设置页 / 关于页用的短名字。
String get kernelName => kRustKernel ? 'Rust' : 'Kotlin';

/// 设置页副标题：内核 + 调用通路。
String get kernelHeadline =>
    kRustKernel ? 'Rust 规则内核 · dart:ffi' : 'Kotlin 规则内核 · MethodChannel';

/// 规则内核报错时抛出，`message` 是可直接展示给用户的中文提示。
class CoreException implements Exception {
  CoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Kotlin 后端：MethodChannel
// ---------------------------------------------------------------------------

const MethodChannel _channel = MethodChannel('qqa/core');

Future<Object?> _invoke(String method, [Object? arguments]) async {
  try {
    return await _channel.invokeMethod<Object?>(method, arguments);
  } on PlatformException catch (error) {
    throw CoreException(error.message ?? '规则内核调用失败');
  } on MissingPluginException {
    throw CoreException('规则内核未注册（非 Android 平台？）');
  }
}

// ---------------------------------------------------------------------------
// Rust 后端：dart:ffi
//
// Rust 侧每个入口收发 UTF-8 C 字符串，内容是 `{"ok":true,"data":...}` 或
// `{"ok":false,"error":"..."}`；返回的字符串必须交回 `qqa_string_free`。
// 这一层把这些细节全部吃掉，调用方只看得到 Dart 值。
// ---------------------------------------------------------------------------

typedef _Str1Native = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _Str1Dart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

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

_Bindings? _ffiCache;
String? _ffiLoadError;

_Bindings get _bindings {
  final cached = _ffiCache;
  if (cached != null) return cached;
  try {
    return _ffiCache = _Bindings(DynamicLibrary.open('libqqa_core.so'));
  } on Object catch (error) {
    _ffiLoadError = '核心库加载失败：$error';
    rethrow;
  }
}

Pointer<Utf8> _call(_Str1Dart fn, String argument) {
  final arena = Arena();
  try {
    return fn(argument.toNativeUtf8(allocator: arena));
  } finally {
    arena.releaseAll();
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

Object? _ffiInvoke(_Str1Dart fn, String argument) => _decode(_call(fn, argument));

// ---------------------------------------------------------------------------
// 对外 API（两套后端共用）
// ---------------------------------------------------------------------------

/// 归一化用户输入的地址，得到裸的 `https://host[:port]`；失败抛 [CoreException]。
Future<String> normalizeOrigin(String input) async {
  final data = kRustKernel
      ? _ffiInvoke(_bindings.origin, input)
      : await _invoke('origin', input);
  if (data is! String) throw CoreException('规则内核返回了非字符串结果');
  return data;
}

/// 同 [normalizeOrigin]，但失败返回 null。
Future<String?> tryNormalizeOrigin(String input) async {
  try {
    return await normalizeOrigin(input);
  } on CoreException {
    return null;
  }
}

/// 一次算好一张快照要显示的全部标签。
Future<Map<String, Object?>> describe(Map<String, Object?> input) async {
  final data = kRustKernel
      ? _ffiInvoke(_bindings.describe, jsonEncode(input))
      : await _invoke('describe', input);
  if (data is! Map) throw CoreException('规则内核返回了非对象数据');
  return data.cast<String, Object?>();
}

/// 批量折叠触发预览，一次调用搞定整个会话列表。
Future<List<String>> previews(List<String> items) async {
  final data = kRustKernel
      ? _ffiInvoke(_bindings.previews, jsonEncode({'items': items}))
      : await _invoke('previews', {'items': items});
  if (data is! List) throw CoreException('规则内核返回了非列表数据');
  return data.map((row) => '$row').toList();
}

/// 概览大卡：连接文案 + 指标数字。
Future<Map<String, Object?>> statusView(Map<String, Object?> input) async {
  final data = kRustKernel
      ? _ffiInvoke(_bindings.statusView, jsonEncode(input))
      : await _invoke('statusView', input);
  if (data is! Map) throw CoreException('规则内核返回了非对象数据');
  return data.cast<String, Object?>();
}

String? _statusCache;

/// 内核健康状态，同步读预热好的缓存（设置页在 build 里直接调）。
String coreStatus() => _statusCache ?? '内核未就绪';

/// 启动时预热一次，让设置页第一帧就有内容。
Future<void> warmCore() async {
  try {
    if (kRustKernel) {
      final data = _ffiInvoke(_bindings.version, '');
      final version = data is Map ? data['version'] : null;
      _statusCache = 'qqa_core $version';
      return;
    }
    final data = await _invoke('version');
    final version = data is Map ? data['version'] : null;
    _statusCache = 'qqa_core $version';
  } on CoreException catch (error) {
    _statusCache = error.message;
  } on Object catch (error) {
    _statusCache = _ffiLoadError ?? '$error';
  }
}
