# 规则内核两个版本：Rust 与 Kotlin

QQA 助手的「格式规则层」（状态文案、计数压缩、token 单位、耗时、CQ 码折叠、地址校验……）
现在在仓库里有两份**语义等价**的实现，同时存在：

| 目录 | 语言 | 角色 |
|---|---|---|
| `rust/` | Rust 2021，crate `qqa_core` 0.1.0 | **参考实现**。不参与打包，用来跑 `cargo test`、生成黄金向量、需要时用 `dart:ffi` 换回来 |
| `android/app/src/main/kotlin/cn/local/qqa/qqa_assistant/QqaCore.kt` | Kotlin | **出厂实现**。v1.4.x 起 App 真正调的就是它，经 MethodChannel |

一句话选型：**发出去的 App 用 Kotlin**（少一份 .so、少一层 ABI 兼容面、编译期就能查错、没有 C 字符指针要管）；
**算法要改、要跑 benchmarks、要脱离 Android 单独验证时用 Rust**（`cargo test` 秒级、可以纯命令行跑）。

---

## 1. 代码规模

| 文件 | 行数 | 内容 |
|---|---|---|
| `rust/src/rules.rs` | 444 | 纯规则，零 IO、零依赖（只有 `std`） |
| `rust/src/lib.rs` | 364 | C ABI 桥（5 个导出符号）+ `dispatch` 通道语义 + 5 个单测 |
| `rust/src/bin/golden.rs` | 225 | 黄金向量生成器（111 条） |
| `QqaCore.kt` | 442 | 上面前两个文件的 Kotlin 对应物（`object`，全部 `@JvmStatic` 语义） |
| `QqaCoreTest.kt` | 182 | 11 个单测，断言逐条抄自 `rules.rs` 的 `#[test]` |
| `GoldenParityTest.kt` | 83 | 读 `golden.json`，110 条逐条比对 |

两版的**函数清单是同一份**：`fontPercent` / `origin` / `sameOrigin` / `profileName` / `chatTitle` /
`statusLabel` / `count` / `oneDecimal` / `tokenCount(In)` / `percent` / `previewText` / `elapsed` /
`compactElapsed` / `toolTiming`，加上两个组合口 `describe` / `statusView`。

---

## 2. 调用通路

Rust 版（v1.4.0 之前）：

```
Dart  lib/core/ffi.dart
  └─ dart:ffi  DynamicLibrary.open('libqqa_core.so')
       └─ lookupFunction<...>  ──同步、同线程、裸指针──►  rust/src/lib.rs
                                                            └─ envelope() → CString::into_raw()
       ◄── 返回 *mut c_char，Dart 必须再调 qqa_string_free 回收
```

Kotlin 版（v1.4.0 起）：

```
Dart  lib/core/core.dart
  └─ MethodChannel('qqa/core').invokeMethod(method, args)   ──异步、跨 isolate──►  MainActivity.configureFlutterEngine
                                                                                     └─ QqaCore.handle(method, args)
  ◄── PlatformException(message) / Map / String / Long      ◄── 标准编码，无手工内存管理
```

差别落在三处：

1. **同步 vs 异步**。FFI 是同步调用，Dart 侧再套 `compute`/`Isolate` 才能不卡 UI；MethodChannel 天生异步，
   但结果回到 Dart 时要过一次事件循环（一次往返通常在几十微秒量级）。
2. **内存**。C 字符串要人管生命周期，忘了 `qqa_string_free` 就漏；MethodChannel 走标准编解码，不存在这个问题，
   代价是每个参数都要序列化一遍。
3. **失败表现**。FFI 里「错误」只能编码进 JSON（`{"ok":false,"error":...}`）或者返回 null 指针；
   Kotlin 侧直接 `throw RuleException`，Dart 收到 `PlatformException` 再包成 `CoreException`。

对本项目来说这三条都不构成瓶颈：这些规则单次执行都在**微秒级**，一次 `/api/status` 的 HTTP 往返是**几十毫秒**，
格式化的开销占比不到千分之一。真正让人不想留 FFI 的是另外两件事——见第 5 节。

---

## 3. 构建链

| | Rust 版 | Kotlin 版 |
|---|---|---|
| 编译 | `rustup target add aarch64-linux-android` + NDK clang 当 linker | 无额外工具链，跟着 `./gradlew` 走 |
| 命令 | `cargo build --release --target aarch64-linux-android` | `flutter build apk` |
| 产物 | `libqqa_core.so` 手动拷进 `android/app/src/main/jniLibs/<abi>/` | 直接编进 APK 的 dex |
| ABI | 每个 ABI 一份 .so，忘了拷哪个架构 → 装上闪退 / `UnsatisfiedLinkError` | 一份 dex 全架构通用 |
| 依赖 | `serde` + `serde_json`（编译期拉一堆） | 0（`org.json` 只在**测试**里用） |
| 环境变量 | `RUSTUP_HOME` / `CARGO_HOME` / `CC_aarch64_linux_android` | `JAVA_HOME`（必须 JDK 21，JDK 25 会让 Kotlin 的 `JavaVersion.parse` 抛异常） |

Kotlin 版把「构建」这件事从两道工序减成一道，是这个重写最直接的收益。

---

## 4. 产物与体积

实测（release，`opt-level="z"` + LTO + strip）：

- `libqqa_core.so`（arm64-v8a）= **405,432 B ≈ 396 KB**；`x86_64` 同级。
- 通用包要带两份 → 约 **0.8 MB**。
- APK 变化：v1.3.0（带 .so）= 20,880,249 B → v1.4.3（Kotlin）= 20,558,119 B，**少了 322 KB**，
  而这中间还**新增**了 `lib/design/motion.dart` 一整套动效代码。也就是纯 .so 的净节省被新功能抵掉了一部分。

> 注意 `.so` 在 APK 里默认不压缩（4 字节对齐直接存），所以 .so 多大，包就大多少。

---

## 5. 为什么最终把出厂实现换成 Kotlin

1. **ABI 事故链**。带 .so 的版本曾经出过「手机装不上，提示与 64 位系统不兼容」——
   `build.gradle.kts` 里多平台串 `android-arm,android-arm64,android-x64` 的 `when` 分支命中了 `android-x64`，
   打出来是 x86_64-only 包。这类问题只能在装机时暴露。Kotlin 版没有「按 ABI 挑库」这回事，整类故障消失。
2. **少一份要维护的二进制**。以前每次改规则都要 `cargo build` → 拷 .so → 重新打包，还要核对两个架构都换了。
3. **调试体验**。Kotlin 侧错误是带行号的 Java 异常；Rust 侧隔着 FFI 只能看到一串 JSON 或一个空指针。
4. **热重载**。改 Kotlin 直接 rebuild；改 Rust 要先过一遍 NDK 交叉编译。

反过来，Rust 版留着的好处是：`cargo test` 12 个用例 0.1 秒跑完，不依赖 Android SDK；
规则的「真值」有一份独立语言写的对照物，**跨语言实现最怕的就是两边悄悄漂移**——现在这件事被 `golden.json` 挡住了。

---

## 6. 语义上的硬坑（两版都必须遵守）

这些是移植时真踩到的，写在这里免得下次重犯：

| 坑 | 现象 | 正确做法 |
|---|---|---|
| 四舍五入方式 | `count(11500)` 若用「银行家舍入」会得 `1.1万` | 必须 **half away from zero**：`floor(x + 0.5)`，Rust `f64::round()` 就是这个语义 |
| `11500` 为什么是 `1.2万` | 11500/10000.0 在 IEEE double 里乘 10 恰好落在 11.5 上，再远离零 → 12 | 别"优化"成整数除法 |
| 小数末尾 | `2.0s` 要显示成 `2s` | 格式化一位小数后 `trim_end_matches(".0")` / `removeSuffix(".0")` |
| 码点 vs char | `profileName` 限 8 个字符，用 UTF-16 `char` 数会把 emoji 劈成两半 | Rust 用 `chars()`，Kotlin 用 `codePointAt`/`appendCodePoint` |
| C 字符串里的 NUL | 用户文本含 `\0` 会让 `CString::new` 失败 | Rust 侧先 `replace('\0', "")`；Kotlin 侧无此问题 |
| 负数/未知 | 计数 `-1` → `—`，token `-1` → `— tok`，耗时 `-1` → `未知` / `用时未知`，比例 `-1` → `—` | 每条规则入口先判 `< 0` |
| 比例钳制 | `1.4` 要显示 `100%` 而不是 `140%` | `clamp(0, 1)` 后再乘 100 |
| 测试里的小数 | org.json 把 `0.5` 解析成 `BigDecimal`，`toLong()` 会截成 `0` | 归一化时先判整数值，再决定用 Long 还是 Double 表达 |

---

## 7. 两版如何保持同步（黄金向量）

`golden.json` **不是手写的**，是 Rust 跑出来的：

```bash
cd rust
export RUSTUP_HOME=/e/toolchains/rustup CARGO_HOME=/e/toolchains/cargo PATH="/e/toolchains/cargo/bin:$PATH"
cargo test                       # 12 passed（7 条规则 + 5 条 C ABI/dispatch）
cargo run --bin golden           # → android/app/src/test/resources/golden.json（111 条）
```

生成器遍历 `qqa_core::dispatch` 的整张方法表，覆盖：地址归一 13 例（含端口 443 折叠、大写、带账号密码、
带路径/参数/#、IPv6）、预览批量 3 例、计数 13 例、token 单位 13 例（auto/m/b/k 各档 + 边界）、
比例 6 例、耗时 20 例、工具耗时 6 例、命名 10 例、状态 13 例、预览折叠 6 例、`describe` 3 例、`statusView` 4 例。

Kotlin 侧拿同一批输入回放：

```bash
cd android
export JAVA_HOME="/c/Program Files/Java/jdk-21.0.10"
./gradlew :app:testReleaseUnitTest     # 12 tests：QqaCoreTest 11 + GoldenParityTest 1
```

`GoldenParityTest` 逐条断言 `QqaCore.handle(method, args)` 的输出与 `expect` 相等（失败用例断言错误文案相等），
把 110 条全过一遍。**改了任何一边没改另一边，这里立刻红。**

两个已知的有意差异，测试里显式跳过：

- `version`：Rust 回 `qqa_core 0.1.0`，Kotlin 回 `qqa_core 1.0.0`，各自跟随自己的构建线，不参与比对。

> 为什么跑 `testReleaseUnitTest` 而不是 `testDebugUnitTest`：debug 变体要去
> `storage.googleapis.com` 拉 flutter engine 的调试 jar，本机不通；release 变体的 jar 早就缓存了。
> 另外 `android.jar` 里的 `org.json` 在 JVM 上是空壳，所以 `golden` 测试额外引了 `org.json:json:20240303`。

---

## 8. 想换回 Rust 怎么办

Rust 代码是完整可用的，换回去只要改 Dart 一层，Kotlin 侧不用动：

1. `cargo build --release --target aarch64-linux-android`（x86_64 同理），把 `libqqa_core.so`
   放进 `android/app/src/main/jniLibs/<abi>/`；`rust/Cargo.toml` 的 `crate-type` 已经含 `cdylib`。
2. `lib/core/core.dart` 的 `MethodChannel` 换回 `dart:ffi`（v1.2.1 的 `lib/core/ffi.dart` 在公开仓
   历史里，`git show ea4995e:lib/core/ffi.dart` 可以直接取回）。
3. `lib/main.dart` 的 `await warmCore()`、`settings_screen` 的「Kotlin 规则内核」文案跟着改。

> 出厂包**不要**同时带 .so 和 Kotlin 内核：两份真值同时在线，等漂移了没人查得出来。
> 要对照就跑第 7 节的黄金向量，那是唯一该有的对照方式。

---

## 9. 什么时候该选哪个（结论表）

| 场景 | 选 |
|---|---|
| 发到用户手机的 APK | **Kotlin**（少一层 ABI、少一份二进制、错误可读） |
| 纯规则算法的开发/调试/压测 | **Rust**（`cargo test` 秒级、可脱离 Android 跑） |
| 需要被别的语言/桌面端复用同一套规则 | **Rust**（`cdylib`/`rlib`，导出即用） |
| 团队里没有 Rust 经验 | **Kotlin**（和 App 同一门语言，改一行就能上线） |
| 要在 UI 线程上高频调用（每帧级别） | **Rust**（FFI 同步、无事件循环往返） |
