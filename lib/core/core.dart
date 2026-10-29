// Dart 侧规则内核入口 —— 后端是 Kotlin（`android/.../QqaCore.kt`）。
//
// 原来这里走 `dart:ffi` 调 Rust 的 `libqqa_core.so`，现在换成一条 MethodChannel
// `qqa/core`：同样的五个方法、同样的语义（`origin` / `describe` / `previews` /
// `statusView` / `version`），只是搬到了 Kotlin 里跑，不再需要 NDK 产物。
//
// 规则函数是纯函数且极便宜，但仍然全是异步 —— 平台通道本身是异步的，
// 所以调用点要么在 async 流程里 await，要么像概览卡那样先把结果缓存进
// `AppState`，让 build 读缓存（见 `AppState.heroLabels`）。

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('qqa/core');

/// 规则内核报错时抛出，`message` 是可直接展示给用户的中文提示。
class CoreException implements Exception {
  CoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<Object?> _invoke(String method, [Object? arguments]) async {
  try {
    return await _channel.invokeMethod<Object?>(method, arguments);
  } on PlatformException catch (error) {
    throw CoreException(error.message ?? '规则内核调用失败');
  } on MissingPluginException {
    throw CoreException('规则内核未注册（非 Android 平台？）');
  }
}

/// 归一化用户输入的地址，得到裸的 `https://host[:port]`；失败抛 [CoreException]。
Future<String> normalizeOrigin(String input) async {
  final data = await _invoke('origin', input);
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
  final data = await _invoke('describe', input);
  if (data is! Map) throw CoreException('规则内核返回了非对象数据');
  return data.cast<String, Object?>();
}

/// 批量折叠触发预览，一次通道搞定整个会话列表。
Future<List<String>> previews(List<String> items) async {
  final data = await _invoke('previews', {'items': items});
  if (data is! List) throw CoreException('规则内核返回了非列表数据');
  return data.map((row) => '$row').toList();
}

/// 概览大卡：连接文案 + 指标数字。
Future<Map<String, Object?>> statusView(Map<String, Object?> input) async {
  final data = await _invoke('statusView', input);
  if (data is! Map) throw CoreException('规则内核返回了非对象数据');
  return data.cast<String, Object?>();
}

String? _statusCache;

/// 内核健康状态，同步读预热好的缓存（设置页在 build 里直接调）。
String coreStatus() => _statusCache ?? '内核未就绪';

/// 启动时预热一次，让设置页第一帧就有内容。
Future<void> warmCore() async {
  try {
    final data = await _invoke('version');
    final version = data is Map ? data['version'] : null;
    _statusCache = 'qqa_core $version';
  } on CoreException catch (error) {
    _statusCache = error.message;
  }
}
