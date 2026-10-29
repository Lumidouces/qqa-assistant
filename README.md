# QQA 助手 · Rust + Flutter 重写版

基于 `QQA-Assistant-Public-1.0.4` 的**逻辑**重写的 Android 客户端。
界面按深色 OLED + 绿色强调的视觉稿重做，底层换成 Rust 核心 + Flutter UI。

- 包名：`cn.local.qqa.qqa_assistant`（与原版一致，可覆盖安装需先卸载，签名不同）
- 版本：1.3.0
- 产物：`dist/QQA-Assistant-RustFlutter-arm64-v1.3.0.apk`（19.9 MB，arm64-v8a）

### 1.3.0 变更（设置页对齐 SleepDown + 液态玻璃标签栏）

排版与动效整体对齐 `Lumidouces/SleepDown-Schedule`（Apache-2.0 上游视觉语言复刻）：

- **设置页重排**：`_PageTitle` 大标题 → 应用卡（56 圆角渐变图标 + 名称 + 副标题 + 右侧版本号）→
  分组小标题（应用 / 刷新 / 外观 / 其他）+ 24 圆角分组卡 + 行内 1px hairline（左缩进 56）+
  每行 23dp 彩色图标 + 标题/副标题 + 右侧值/开关/箭头。行高级度与上游 `SettingsRows` 一致。
- **底部标签栏换成液态玻璃**：新增 `lib/design/liquid_tabs.dart` 的 `LiquidTabBar`，
  替换原 `GlassDock`。语义照搬上游 `HomeDockTabs` / `LiquidBottomTabs`：
  - 跟手拖动 + 落格：`AnimationController.unbounded` + `SpringSimulation`
    （`SpringDescription.withDampingRatio(mass: 1, stiffness: 1000, ratio: 1)`）
  - 按下缩放 78 → 56（与上游 `DampedDragAnimation` 同值）
  - 指示器宽度溢出 8 / 高度溢出 4，透镜高 12 / 强度 17（`indicatorWidthOverflow` 等常量逐项对齐）
  - 容器高 54、指示器高 46、容器透明度 dark 0.45 / light 0.54
  - `_HighlightPainter` 径向光斑：highlight 0.07 / shadow 0.05 / innerShadow 0.08，
    chromaticAberration 开关保留
- 修掉设置页「当前连接」行 subtitle 与右侧值重复显示同一个域名的老问题（右侧改「已连接 / 未配置」）。
- 修掉一个材质坑：把 `highlightAlpha`/`shadowAlpha` 传成 1 时，暗色主题下整条胶囊被顶缘反光刷成白板，
  已按上游 0.07/0.05/0.08 回落。

### 1.2.2 变更（修 ABI：真机装不上）

`build.gradle.kts` 的 `resolvedAbi` 判断顺序有 bug：`flutter build apk --release`
不带 `--target-platform` 时传的是 `-Ptarget-platform=android-arm,android-arm64,android-x64`
（三个都在），原来先匹配 `android-x64` 就赢了，于是打出来的是 **x86_64-only** 的包 ——
真机安装报「该应用与64位系统不兼容」。

- `resolvedAbi` 改为优先匹配 `android-arm64`，再 `android-x64`，最后 `android-arm`。
- 新增 `tools/check-apk-abi.sh`：发布前校验 APK 里的 ABI 集合 + `libqqa_core.so`
  的 ELF machine（183=aarch64 / 62=x86_64），不匹配就非零退出。
- 现在 `flutter build apk --release` 直接出 arm64-v8a 单 ABI 包，模拟器跑用
  `-PtargetAbi=x86_64`。

### 1.2.1 变更（token 单位阶梯）

- 新增 `lib/core/tokens_fmt.dart`：`formatTokens(value, scale)` 三档 —— `auto` 按数量自动选（≥10 亿 B / ≥100 万 M / ≥1000 k）、`mega` 固定 M、`kilo` 固定 k。
- 总 tokens 数字可点，循环切换三档；选择写进 `SharedPreferences`（`token_scale`），重开保留。设置 → 外观里也有选择器 + 实时示例。
- Rust `rules::token_count_in(value, unit)` 与 Dart 端算法对齐；`qqa_describe` / `qqa_status_view` 读 `tokenUnit` 字段。
- 修掉 k 档旧 bug：小于 1000 不再输出 `0.5k`，直接给原数。
- 新增 `lib/core/version.dart` 作为版本号唯一来源，设置页不再写死字符串。

### 1.2.0 变更（UI 重构：玻璃拟态）

按 `Lumidouces/SleepDown-Schedule` 的视觉语言整体重做，交互与网络层不变：

- 新增 `lib/design/` 设计层：`tokens.dart`（色阶/间距/圆角/字号）、`glass.dart`（GlassPanel / GlassChrome / GlassDock / GlassScope）、`theme.dart`。
- 五页全部重写：总览改数据卡 + 环形用量，过程改时间线会话卡，存档改聊天气泡，操作改分组动作卡，设置改滑块式参数。
- 支持浅/深两套色阶，跟随系统；底部 Dock 用模糊玻璃 + 选中态高亮。
- 路由仍是 `IndexedStack`，切页不重建，滚动位置保留。

### 1.1.0 变更（对接真实控制台）

1.0.0 只跑过自写的 mock，字段名与真实 `/api/*` 有出入，1.1.0 按真实响应全部改掉：

| 位置 | 真实形状 | 处理 |
|---|---|---|
| 会话列表 | 无 `sentCount`；`usage.calls` 是**模型调用次数**（每条 ≥1） | 「已回复」改用 `status == 'done'` 计数，不再用 `sentCount > 0`（否则永远是 50/50） |
| 会话详情 | `sent[]` 恒为空，对话在 `messages[]` 里 | 有 `messages` 就渲染，`sent` 有内容才显示 |
| 消息条目 | 两种形状：`{role, content}` 与 `{toolCall:{name,args,result}}` | 两种都渲染；工具调用单独成卡，`isError` 标红 |
| 触发内容 | 列表用 `trigger` 字符串，详情用 `triggerSummary` / `triggerText` | 三选一兜底 |
| 群消息 | 无 `role`，但有 `senderName` + 毫秒 `at` | 气泡上方显示发言人，右下角显示 `HH:mm` |
| 状态 | `onebot.self.nickname`、`usage.runs`、`cost` | 状态卡多一枚昵称 chip；花费按真实 `cost` 显示 |

## 和原版的关系

**保留**（与原版逐字对齐，重写时照抄契约）：

- 8 个 `/api/` 端点：`status` / `sessions` / `chats` / `chats/{key}/messages` /
  `sessions/{id}` / `skills` / `pause`。
- 只允许 `/api/` 前缀、禁 `..`；10 MB 上限；10s 连接 / 15s 读超时。
- 错误文案逐条对齐（401/403、502/503、证书失败、连不上、超时）。
- 两个账号槽、地址规范化（必须 `https:`、不带 `/api` 与查询串）。
- 5 个页面：总览 / 日志（会话过程 + 消息存档）/ 事件 / 操作 / 设置。

**重写**：

| 层 | 原版 | 现在 |
|---|---|---|
| UI | Java 手写 View（714 行 MainActivity） | Flutter，深色 + 绿色，卡片圆角 16-20 |
| 核心 | 全在 Java 里 | Rust `qqa_core`（FFI：cdylib）做地址校验、CQ 码清洗、文本截断、时间格式化 |
| 请求 | `HttpsURLConnection` | `dart:io HttpClient` |
| 设置 | SharedPreferences 散落 key | `AppStore` 统一封装，schema 化 |

## 构建

```bash
# 需要：Flutter 3.35.x、Android SDK 35 + NDK 27、Rust（x86_64-pc-windows-gnu host）
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn   # 必须，否则 engine jar 只有 40KB/s

# 1. Rust 核心 → .so
bash tools/build-rust.sh          # 产物进 android/app/src/main/jniLibs/{arm64-v8a,x86_64}

# 2. 打包
flutter build apk --release --target-platform android-arm64   # 真机
flutter build apk --debug   --target-platform android-x64     # 模拟器
```

`android/app/build.gradle.kts` 里的 `resolvedAbi` 会把 `-Ptarget-platform` 映射成
`abiFilters`，**不要**只传 `--target-platform` 就以为打进去了——Flutter 不设
`targetAbi`，不映射的话 APK 里会缺 `libflutter.so`，装上就闪退。

## 本地跑（模拟器 + mock 服务）

```bash
node tools/mock-qqa.mjs                                    # 127.0.0.1:8788
bin/cf.exe tunnel --url http://127.0.0.1:8788 --no-autoupdate  # 拿 https 地址（App 只收 https）
adb install -r dist/...apk && adb shell am start -n cn.local.qqa.qqa_assistant/.MainActivity
```

App 只接受 `https:` 地址，所以本机 mock 必须经隧道或自签证书，不能直连 `http://127.0.0.1:8788`。

## 已验证

**1.1.0 对真实控制台**（服务器 `47.108.210.180` 上跑着的 QQA，经 cloudflared 隧道
`https://gibraltar-shakira-faced-owen.trycloudflare.com`），Android 15 API 35 x86_64 模拟器实测：

- `tools/g2.png` 总览：真实机器人 `哦鲸鲸`、模型 `mimo-v2.6-flash`、52 次调用、23 条已回复、
  2287.9k tokens、花费 ¥0.59、缓存命中 77%
- `tools/g3.png` 消息存档：13 个真实群 / 私聊会话，带最后一句预览与消息数
- `tools/g6.png` 会话详情：轮次/工具/模型/tokens 徽章 + 触发内容 + 模型过程（含 `finish` 工具调用
  报错原文）
- `tools/g4.png` 操作页、`tools/g5.png` 设置页（`qqa_core 0.1.0` 已加载）

拼图：`tools/real-contact-sheet.png`

**1.0.0 对 mock**（`tools/mock-qqa.mjs`）：`d-overview.png` / `d-logs.png` / `d-detail.png` /
`d-events.png` / `d-chat.png` / `d-tools.png` / `d-paused.png` / `d-settings.png`。
`pause` 真打接口验证：点「暂停」后 `GET /api/status` 返回 `paused: true`，恢复后 `false`。

## 远程连接（手机访问自己电脑上的 QQA）

QQA 控制台只监听 `127.0.0.1:3210`，而且**校验 `Host` / `Origin` 必须等于 `127.0.0.1:3210`** ——
直接套反向代理或公网隧道会被回 `403 {"error":"请求来源不被信任（仅接受本机控制台的同源请求）"}`。

`tools/start-qqa-chain.sh` 把整条链路一次拉起：

```
手机 → cloudflare 快速隧道 → 本机 13211（tools/qqa-proxy.js 改写 Host/Origin）
     → ssh -L 13210 → 服务器/本机 127.0.0.1:3210
```

跑完脚本会打印一个 `https://xxx.trycloudflare.com` 地址，直接填进 App「电脑地址」。
注意快速隧道**每次重启域名都会变**，脚本会自己重试到拿到能用的地址为止。

停：`pkill -f qqa-proxy.js; pkill -f "13210:127.0.0.1:3210"; pkill -f cf.exe`

## 实测踩到的坑

1. **模拟器 `-no-window` 必须加**。带窗口跑几次都被宿主杀掉（`qemu` 进程凭空消失），
   无窗口模式稳定。启动用 `powershell Start-Process` 或后台 job，别用 `nohup &`。
2. **Git-Bash 会篡改 adb 参数**。`adb pull /sdcard/x.png tools/x.png` 会把 `/sdcard` 当路径转换，
   报 `failed to stat remote object 'C:/.../sdcard/x.png'`。必须 `export MSYS2_ARG_CONV_EXCL='*'`。
3. **换签名要卸载**。debug 与 release 签名不同，`INSTALL_FAILED_UPDATE_INCOMPATIBLE` 时先
   `adb uninstall cn.local.qqa.qqa_assistant`。
4. **预置账号用 `run-as`**。模拟器上想跳过手输地址，直接把 `FlutterSharedPreferences.xml`
   push 进 `shared_prefs/`（`adb shell run-as cn.local.qqa.qqa_assistant cp ...`）。

## 测试

```
flutter analyze   → No issues found
flutter test      → 7 passed（Rust 侧 cargo test 8 passed）
```
