import 'package:flutter/foundation.dart';

/// 玻璃画质档位 —— 对齐上游 SleepDown-Schedule 的
/// `AppMaterialLevel { QUALITY, PERFORMANCE, SUPER_PERFORMANCE }`。
///
/// 上游在弱机上不掉帧，靠的不是语言（Kotlin / Compose 只是宿主），而是这套
/// 「材质策略」：负载高时不硬扛，直接砍掉背景采样、简化模糊。Flutter 侧的
/// 等价实现就是下面三档。
enum GlassQuality {
  /// 逐帧折射着色器 + 高光 + 内阴影，最接近设计稿。
  high('高画质', '逐帧折射 + 高光 + 内阴影'),

  /// 只做高斯模糊，跳过着色器（省掉一次背景采样与折射计算）。
  balanced('均衡', '只做模糊，不折射'),

  /// 完全不采样背景，纯半透明底色 —— 等同上游 SUPER_PERFORMANCE。
  off('省电', '不采样背景，纯色半透明');

  const GlassQuality(this.label, this.hint);

  final String label;
  final String hint;

  String get wire => name;

  static GlassQuality fromWire(String? raw) => GlassQuality.values.firstWhere(
        (item) => item.wire == raw,
        orElse: () => GlassQuality.high,
      );
}

/// 全局画质开关：材质层与设置页共享同一个实例，改档位即刻重绘全部玻璃。
final ValueNotifier<GlassQuality> glassQuality =
    ValueNotifier<GlassQuality>(GlassQuality.high);
