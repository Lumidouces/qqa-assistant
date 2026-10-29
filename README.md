# QQA 助手 · Kotlin + Flutter 重写版

基于 `QQA-Assistant-Public-1.0.4` 的**逻辑**重写的 Android 客户端。
界面是深色玻璃拟态 + 液态玻璃标签栏；规则内核有 **Kotlin** 与 **Rust** 两个等价实现，
同一版本号出两份 APK 并存，功能与界面完全一致，只有内核通路不同。

- 包名：`cn.local.qqa.qqa_assistant`（与原版一致，签名不同，覆盖安装前需先卸载）
- 版本：1.4.4
- 产物（任选其一，装前先卸载另一个）：
  - `QQA-Assistant-arm64-v1.4.4-kotlin.apk` — Kotlin 内核（MethodChannel），19.6 MB，**推荐默认**
  - `QQA-Assistant-arm64-v1.4.4-rust.apk` — Rust 内核（dart:ffi），20.0 MB

## 两个版本各自的优势

**Kotlin 版**
- APK 更干净：没有额外原生库，不存在 `.so` 与 ABI 不匹配导致的「无法安装」；21 MB 内只有 `libflutter.so` / `libapp.so`。
- 同进程 JVM 调用，不过 NDK 边界；规则代码直接随 `./gradlew :app:testReleaseUnitTest` 在 JVM 上跑单测。
- 构建只依赖 JDK 21，不需要 Rust 工具链和 NDK 交叉编译，clone 下来 `flutter build apk` 就能出包。
- 规则层异常是普通 Kotlin 异常，堆栈可读、可断点。

**Rust 版**
- 同一份规则可被非 Flutter 前端复用（CLI / 服务端 / 桌面端），暴露稳定的 C ABI（`qqa_*` 符号）。
- 纯计算零 GC 压力：格式化、CQ 码折叠、预览截断都在原生侧完成，高频刷新更省内存。
- 内存安全由编译器保证；规则代码可以脱离 Android 用 `cargo test` 验证。
- 需要「一套内核多端共用」时只有 Rust 能做，Kotlin 版绑死 Android。

切换方式：卸载重装即可，两者共用同一份本地设置（地址存 DataStore，与内核无关）。

## 自己构建这两种包

```bash
# Kotlin 内核（默认，不带 --dart-define）
flutter build apk --release --target-platform android-arm64

# Rust 内核：先编 .so，再带上开关
bash tools/build-rust.sh                       # 产出 rust/target/*/release/libqqa_core.so
cp rust/target/arm64-v8a/libqqa_core.so android/app/src/main/jniLibs/arm64-v8a/
flutter build apk --release --target-platform android-arm64 --dart-define=QQA_KERNEL_RUST=true
```

内核选择在 `lib/core/core.dart`：`const kRustKernel = bool.fromEnvironment('QQA_KERNEL_RUST')`，
为 true 走 `dart:ffi` 打开 `libqqa_core.so`，为 false 走 `MethodChannel('qqa/core')` 调 `QqaCore`。

### 1.4.4 变更（规则内核 Rust 版回归，作为参考实现并存）

- `rust/` 目录重新入库：`qqa_core` 0.1.0 完整回归（`rules.rs` 444 行 + `lib.rs` 364 行 + `bin/golden.rs`）。
  默认不参与打包（出厂是 Kotlin 内核）；加 `--dart-define=QQA_KERNEL_RUST=true` 编出来的就是 Rust 内核包，两份 APK 同版本号并存。
- `lib.rs` 里把 `qqa_describe` / `qqa_status_view` 的正文抽成 `describe_payload` / `status_view_payload`，
  并新增 `pub fn dispatch(method, args)`：和 Kotlin `QqaCore.handle` 同一张方法表（version / origin /
  previews / describe / statusView + 13 条单规则）。
- 新增 `cargo run --bin golden`：跑 Rust 参考实现生成 `android/app/src/test/resources/golden.json`，
  共 111 条向量；`GoldenParityTest` 在 Kotlin 侧逐条回放比对（跳过 `version`，两边各自维护版本号）。
  以后改任何一边没改另一边，`./gradlew :app:testReleaseUnitTest` 直接红。
- 新增 `docs/KERNEL-RUST-VS-KOTLIN.md`：两版在调用通路、构建链、体积、错误语义、Unicode/舍入坑、
  换回 Rust 的步骤上的完整对比。
- App 侧无行为变化（Kotlin 内核只多了几条通道分发口，界面走的仍是 `describe` / `statusView` 组合口）。

### 1.4.3 变更（一轮 bug 清扫）

- **断开连接会丢常用入口**：`connect()` / `disconnect()` 重建 `Account` 时把 `quickAccess`
  一起丢了，重连后快捷入口清零。现在两处都沿用槽位原有的偏好。
- **换号/断开后旧数据回流**：在飞行中的请求回来时会把刚清空的会话又写回界面。
  加了 `_epoch` 世代号，换号、重连、断开都自增，对不上的响应直接丢弃。
- **会话与预览可能错行**：`sessions` 与 `sessionPreviews` 原先分两次赋值，中间的 notify
  会让新行配上旧预览。现在先取完预览再一起落定；预览失败时退化成空串，不影响列表。
- **规则内核失败后不再重试**：概览卡的 `heroLabels` 签名在失败时也被记下，之后同样状态
  永不重算。现在 `onError` 里把签名作废。
- **断开连接无二次确认**：一按就清地址，只能重新手打 URL。改成先弹确认条。
- **文案过期**：操作页仍写「Rust + Flutter 重写版」，连接页还在教用户登 Tailscale、
  占位符是 `*.tailnet.ts.net`。统一改成 Kotlin 与实际隧道流程；`User-Agent` 也从写死的
  1.0.4 改成跟随 `appVersion`。

### 1.4.2 变更（修「切标签时所有页面叠在一起」）

- 根因：`PageSwitcher` 用 `Stack` + 每页 `AnimatedOpacity`，外层却包了
  `TickerMode(enabled: active)`。切走的那一页 ticker 被关掉，透明度动画卡死在
  1.0，于是新旧两页永久叠在一起。
- 改法：换回 `IndexedStack`（任何时刻只绘制当前页，状态/滚动位置照旧保留），
  过渡改成包在外层的 `FadeTransition` + `SlideTransition`，切页时新页淡入上滑。
  叠层在结构上就不可能发生。

### 1.4.1 变更（修「打开就是空白」）

- **冷启动立刻拉数据**：以前 `AppState` 只装轮询定时器，首个请求要等满一个周期（默认 30 秒），
  期间界面全是「控制台未连接 / 0」，看起来就是坏的。现在构造时立即 `refreshAll()`。
- **切回前台补一次**：`QqaApp` 注册 `WidgetsBindingObserver`，`resumed` 时立刻刷新并重置轮询。
- **错误文案说人话**：连不上时明确提示「临时隧道地址会过期，到设置 → 当前连接换最新地址」，
  不再是一句和现实无关的 Tailscale 提示。

### 1.4.0 变更（内核改 Kotlin + 动效）

- 规则内核从 Rust/FFI 换成 Kotlin + `MethodChannel`，安装包里不再有 `libqqa_core.so`。
- 新增 `lib/design/motion.dart`：切页淡入、列表错峰入场、数字变化上滑换字三组动效。
- `flutter analyze` 干净；JVM 单测 `./gradlew :app:testReleaseUnitTest` → 11 passed。

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
| 核心 | 全在 Java 里 | `QqaCore`（Kotlin，MethodChannel）做地址校验、CQ 码清洗、文本截断、时间格式化；同语义的 Rust `qqa_core` 保留在 `rust/` 作参考实现 |
| 请求 | `HttpsURLConnection` | `dart:io HttpClient` |
| 设置 | SharedPreferences 散落 key | `AppStore` 统一封装，schema 化 |

## 构建

```bash
# 需要：Flutter 3.35.x、Android SDK 35、「JDK 21」（JDK 25 会让 Kotlin 的 JavaVersion.parse 抛异常）
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn   # 必须，否则 engine jar 只有 40KB/s
export JAVA_HOME="/c/Program Files/Java/jdk-21.0.10"

flutter build apk --release --target-platform android-arm64   # 真机
flutter build apk --debug   --target-platform android-x64     # 模拟器
```

规则内核是 Kotlin，**不需要** Rust 工具链，也不需要往 `jniLibs/` 拷 `.so`。

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

## 实测踩到的坑

1. **模拟器 `-no-window` 必须加**。带窗口跑几次都被宿主杀掉（`qemu` 进程凭空消失），
   无窗口模式稳定。启动用 `powershell Start-Process` 或后台 job，别用 `nohup &`。
2. **Git-Bash 会篡改 adb 参数**。`adb pull /sdcard/x.png tools/x.png` 会把 `/sdcard` 当路径转换，
   报 `failed to stat remote object 'C:/.../sdcard/x.png'`。必须 `export MSYS2_ARG_CONV_EXCL='*'`。
3. **换签名要卸载**。debug 与 release 签名不同，`INSTALL_FAILED_UPDATE_INCOMPATIBLE` 时先
   `adb uninstall cn.local.qqa.qqa_assistant`。
4. **预置账号用 `run-as`**。模拟器上想跳过手输地址，直接把 `FlutterSharedPreferences.xml`
   push 进 `shared_prefs/`（`adb shell run-as cn.local.qqa.qqa_assistant cp ...`）。

## 规则内核：两份实现并存

规则层现在有两份语义等价的实现，都在仓库里：

| 位置 | 语言 | 角色 |
|---|---|---|
| `android/app/src/main/kotlin/cn/local/qqa/qqa_assistant/QqaCore.kt` | Kotlin | **出厂实现**，App 经 MethodChannel 调它 |
| `rust/` | Rust（crate `qqa_core`） | **参考实现**，不参与打包；`cargo test` / 生成黄金向量 / 需要时可换回 `dart:ffi` |

两份不许漂移，靠 `android/app/src/test/resources/golden.json` 卡住。这份文件不是手写的，
是 Rust 跑出来的：

```bash
cd rust
export RUSTUP_HOME=/e/toolchains/rustup CARGO_HOME=/e/toolchains/cargo PATH="/e/toolchains/cargo/bin:$PATH"
cargo test                 # 12 passed（7 条规则 + 5 条 C ABI / dispatch）
cargo run --bin golden     # → android/app/src/test/resources/golden.json（111 条向量）
```

Kotlin 侧把同一批输入回放，逐条比对输出：

```bash
cd android
export JAVA_HOME="/c/Program Files/Java/jdk-21.0.10"
./gradlew :app:testReleaseUnitTest   # 12 tests：QqaCoreTest 11 + GoldenParityTest 1（比对 110 条）
```

> 只能跑 `testReleaseUnitTest`：debug 变体要从 `storage.googleapis.com` 拉 flutter engine 的调试 jar，
> 国内不通；release 变体的 jar 已缓存。`golden` 测试另外引了 `org.json:json:20240303`，
> 因为 `android.jar` 里的 `org.json` 在 JVM 上是空壳。

两版的完整对比（调用通路、构建链、体积、错误语义、Unicode/舍入坑、换回步骤）见
[`docs/KERNEL-RUST-VS-KOTLIN.md`](docs/KERNEL-RUST-VS-KOTLIN.md)。

## 测试

```
flutter analyze                      → No issues found
./gradlew :app:testReleaseUnitTest   → 12 tests passed（Kotlin 内核 11 + 跨语言黄金向量 1）
cargo test（rust/）                   → 12 passed
```
