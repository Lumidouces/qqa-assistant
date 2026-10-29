package cn.local.qqa.qqa_assistant

import java.util.Locale
import kotlin.math.floor

/**
 * 规则内核 —— 原 Rust `qqa_core` 的 Kotlin 移植。
 *
 * 只做**纯规则**：地址归一化，以及界面要打印的每一个标签和数字。行为逐条对齐
 * `rust/src/rules.rs`（同一个输入必须给出同一个字符串），所以两边可以互相替换；
 * 现在 Android 侧只跑这一份，Rust 版本保留在 `rust/` 供对照与回归测试。
 *
 * 所有对外方法都在 [handle] 里按方法名分发，供 MainActivity 的 MethodChannel 调用。
 */
object QqaCore {

    const val NAME = "qqa_core"
    const val VERSION = "1.0.0"

    /** 校验类错误：消息就是可以直接展示给用户的中文提示。 */
    class RuleException(message: String) : IllegalArgumentException(message)

    private const val ORIGIN_ERROR =
        "请填写完整 HTTPS 根地址，不含账号密码、路径、参数或 # 标记"

    // ---------------------------------------------------------------- 数字格式

    /** Rust `f64::round` 是「.5 远离零」，Java 的 `Math.round` 是「.5 向正无穷」。 */
    private fun roundHalfAway(value: Double): Double =
        if (value >= 0.0) floor(value + 0.5) else -floor(-value + 0.5)

    /** 保留一位小数，整数位不带尾巴：`1.0` → `1`。 */
    private fun oneDecimal(value: Double): String {
        val rounded = roundHalfAway(value * 10.0) / 10.0
        return String.format(Locale.US, "%.1f", rounded).removeSuffix(".0")
    }

    /** 字体缩放钳到 85%..160%。 */
    fun fontPercent(value: Long): Long = value.coerceIn(85L, 160L)

    /** 大数压缩：`1.2万` / `3.1M`。 */
    fun count(value: Long): String {
        if (value < 0) return "—"
        if (value >= 1_000_000) return "${oneDecimal(value / 1_000_000.0)}M"
        if (value >= 10_000) return "${oneDecimal(value / 10_000.0)}万"
        return value.toString()
    }

    /** `0.85` → `85%`；负数 / 非有限 → `—`。 */
    fun percent(value: Double): String {
        if (!value.isFinite() || value < 0.0) return "—"
        val clamped = value.coerceIn(0.0, 1.0)
        return "${roundHalfAway(clamped * 100.0).toLong()}%"
    }

    /**
     * token 计数格式。
     *
     * 档位 `auto` 之外的偏好来自设置里的「数字单位」：
     * - `auto`：≥1e9 用 B、≥1e6 用 M、≥1e3 用 k，再小给原数
     * - `m`：最高只到 M（131 亿会读成 13146.3M）
     * - `b` / `k`：显式钉住
     */
    fun tokenCountIn(value: Long, unit: String): String {
        if (value < 0) return "— tok"
        val scale = when (unit) {
            "m", "M" -> "m"
            "b", "B" -> "b"
            "k", "K" -> "k"
            else -> "auto"
        }
        val divisor: Double
        val suffix: String
        when (scale) {
            "k" -> {
                if (value < 1_000) return "$value tok"
                divisor = 1_000.0; suffix = "k"
            }
            "m" -> when {
                value >= 1_000_000 -> { divisor = 1_000_000.0; suffix = "M" }
                value >= 1_000 -> { divisor = 1_000.0; suffix = "k" }
                else -> return "$value tok"
            }
            "b" -> when {
                value >= 1_000_000_000 -> { divisor = 1_000_000_000.0; suffix = "B" }
                value >= 1_000_000 -> { divisor = 1_000_000.0; suffix = "M" }
                value >= 1_000 -> { divisor = 1_000.0; suffix = "k" }
                else -> return "$value tok"
            }
            else -> when {
                value >= 1_000_000_000 -> { divisor = 1_000_000_000.0; suffix = "B" }
                value >= 1_000_000 -> { divisor = 1_000_000.0; suffix = "M" }
                value >= 1_000 -> { divisor = 1_000.0; suffix = "k" }
                else -> return "$value tok"
            }
        }
        return "${oneDecimal(value / divisor)}$suffix tok"
    }

    fun tokenCount(value: Long): String = tokenCountIn(value, "auto")

    // ------------------------------------------------------------------ 时间

    /** `12.3 秒` / `3分20秒` / `1时5分`。 */
    fun elapsed(ms: Long): String {
        if (ms < 0) return "未知"
        if (ms < 60_000) return "${String.format(Locale.US, "%.1f", ms / 1000.0)} 秒"
        if (ms < 3_600_000) return "${ms / 60_000}分${(ms % 60_000) / 1000}秒"
        return "${ms / 3_600_000}时${(ms % 3_600_000) / 60_000}分"
    }

    /** `1.4s` / `2m10s` / `1h4m`。 */
    fun compactElapsed(ms: Long): String {
        if (ms < 0) return "用时未知"
        if (ms < 60_000) {
            val text = String.format(Locale.US, "%.1f", ms / 1000.0).removeSuffix(".0")
            return "${text}s"
        }
        if (ms < 3_600_000) return "${ms / 60_000}m${(ms % 60_000) / 1000}s"
        return "${ms / 3_600_000}h${(ms % 3_600_000) / 60_000}m"
    }

    /** 工具调用耗时 + 结果后缀。 */
    fun toolTiming(outcome: String, start: Long, end: Long, duration: Long, now: Long): String {
        if (outcome == "running") {
            return if (start >= 0) "运行中 ${compactElapsed((now - start).coerceAtLeast(0))}" else "运行中"
        }
        val elapsedMs = when {
            duration >= 0 -> duration
            start >= 0 && end >= start -> end - start
            else -> -1L
        }
        val label = StringBuilder(
            if (elapsedMs >= 0) compactElapsed(elapsedMs) else "用时未提供"
        )
        when (outcome) {
            "error" -> label.append("（失败）")
            "timeout" -> label.append("（超时）")
            "ok", "" -> {}
            else -> label.append("（状态未知）")
        }
        return label.toString()
    }

    // ------------------------------------------------------------------ 文本

    /** 展示名最多 8 个码点。 */
    fun profileName(input: String, fallback: String): String {
        val value = input.trim()
        if (value.isEmpty()) return fallback
        val out = StringBuilder()
        var index = 0
        while (index < value.length) {
            val point = value.codePointAt(index)
            out.appendCodePoint(point)
            index += Character.charCount(point)
            if (out.codePointCount(0, out.length) >= 8) break
        }
        return out.toString()
    }

    /** `group:123` / `private:456` 的可读标题。 */
    fun chatTitle(key: String, name: String): String {
        val trimmed = name.trim()
        if (trimmed.isNotEmpty()) return trimmed
        if (key.startsWith("group:")) return "群聊 ${key.removePrefix("group:")}"
        if (key.startsWith("private:")) return "私聊 ${key.removePrefix("private:")}"
        if (key.isEmpty()) return "未命名会话"
        return key
    }

    /** 会话状态 → 中文标签。 */
    fun statusLabel(status: String): String = when (status) {
        "running" -> "处理中"
        "waiting" -> "等待中"
        "error", "failed" -> "失败"
        "delivered" -> "已回复"
        "completed", "ended" -> "已结束"
        "aborted", "stopped" -> "已停止"
        "noreply", "skipped" -> "未回复"
        "" -> "状态未知"
        else -> status
    }

    /** 把触发文本里的 CQ 码折叠成可读内容，空白压成一个空格，超 240 字截断。 */
    fun previewText(value: String): String {
        if (value.isEmpty()) return ""
        val out = StringBuilder(value.length)
        var index = 0
        while (index < value.length) {
            val ch = value[index]
            if (ch == '[' && value.startsWith("[CQ:", index)) {
                val end = value.indexOf(']', index)
                if (end >= 0) {
                    val code = value.substring(index, end + 1)
                    when {
                        code.startsWith("[CQ:reply") || code.startsWith("[CQ:at") -> {
                            val qq = code.substringAfter("qq=", "")
                                .takeWhile { it.isDigit() }
                            if (qq.isNotEmpty()) out.append('@').append(qq)
                        }
                        code.startsWith("[CQ:image") -> out.append("[图片]")
                    }
                    index = end + 1
                    continue
                }
            }
            out.append(ch)
            index++
        }

        val squeezed = StringBuilder(out.length)
        var lastSpace = false
        for (c in out) {
            if (c.isWhitespace()) {
                if (!lastSpace) squeezed.append(' ')
                lastSpace = true
            } else {
                squeezed.append(c)
                lastSpace = false
            }
        }
        val text = squeezed.toString().trim()
        if (text.codePointCount(0, text.length) > 240) {
            val cut = text.offsetByCodePoints(0, 240)
            return "${text.substring(0, cut)}…"
        }
        return text
    }

    // ------------------------------------------------------------------ 地址

    /**
     * 把用户输入的地址归一化成 `https://host[:port]`。
     *
     * 只接受纯 HTTPS 根地址：带账号密码、路径、查询串、`#` 一律拒绝；443 端口collapse 掉。
     */
    fun origin(input: String): String {
        val fail: () -> Nothing = { throw RuleException(ORIGIN_ERROR) }
        val trimmed = input.trim()
        if (trimmed.isEmpty()) fail()

        val sep = trimmed.indexOf("://")
        if (sep < 0) fail()
        val scheme = trimmed.substring(0, sep)
        if (!scheme.equals("https", ignoreCase = true)) fail()
        val rest = trimmed.substring(sep + 3)
        if (rest.contains('#') || rest.contains('?')) fail()

        val slash = rest.indexOf('/')
        val authority = if (slash >= 0) rest.substring(0, slash) else rest
        val path = if (slash >= 0) rest.substring(slash) else ""
        if (path.isNotEmpty() && path != "/") fail()
        if (authority.isEmpty() || authority.contains('@')) fail()

        val host: String
        var port: Long? = null
        if (authority.startsWith("[")) {
            val close = authority.indexOf(']')
            if (close < 0) fail()
            host = authority.substring(1, close)
            val tail = authority.substring(close + 1)
            port = when {
                tail.startsWith(":") -> tail.substring(1).toLongOrNull() ?: fail()
                tail.isEmpty() -> null
                else -> fail()
            }
        } else {
            val colon = authority.lastIndexOf(':')
            if (colon >= 0) {
                host = authority.substring(0, colon)
                port = authority.substring(colon + 1).toLongOrNull() ?: fail()
            } else {
                host = authority
            }
        }
        if (host.isEmpty() || host.contains(' ')) fail()
        val portValue = port
        if (portValue != null && (portValue == 0L || portValue > 65535L)) fail()

        val lower = host.lowercase(Locale.ROOT)
        val bracketed = if (lower.contains(':')) "[$lower]" else lower
        return if (portValue == null || portValue == 443L) {
            "https://$bracketed"
        } else {
            "https://$bracketed:$portValue"
        }
    }

    /** [link] 与 [origin] 同源。 */
    fun sameOrigin(origin: String, link: String): Boolean {
        val base = try {
            origin(origin)
        } catch (_: RuleException) {
            return false
        }
        val sep = link.indexOf("://")
        if (sep < 0) return false
        val scheme = link.substring(0, sep)
        val rest = link.substring(sep + 3)
        val authority = rest.split('/', '?', '#').firstOrNull() ?: ""
        val absolute = "$scheme://$authority/"
        val parsed = try {
            origin(absolute)
        } catch (_: RuleException) {
            return false
        }
        return parsed == base
    }

    // ------------------------------------------------------------- 复合视图

    /** 一次算好一张快照要显示的全部字符串。 */
    fun describe(input: Map<String, Any?>): Map<String, Any?> {
        val status = readString(input, "status")
        val unit = readString(input, "tokenUnit")
        val elapsedMs = readLong(input, "elapsedMs", -1)
        return linkedMapOf(
            "statusLabel" to statusLabel(status),
            "chatTitle" to chatTitle(readString(input, "chatKey"), readString(input, "chatName")),
            "profileName" to profileName(readString(input, "profile"), readString(input, "fallback")),
            "calls" to count(readLong(input, "calls", -1)),
            "tokens" to tokenCountIn(readLong(input, "tokens", -1), unit),
            "totalTokens" to tokenCountIn(readLong(input, "totalTokens", -1), unit),
            "promptTokens" to tokenCountIn(readLong(input, "promptTokens", -1), unit),
            "completionTokens" to tokenCountIn(readLong(input, "completionTokens", -1), unit),
            "cacheReadTokens" to tokenCountIn(readLong(input, "cacheReadTokens", -1), unit),
            "elapsed" to elapsed(elapsedMs),
            "compactElapsed" to compactElapsed(elapsedMs),
            "toolTiming" to toolTiming(
                readString(input, "outcome"),
                readLong(input, "start", -1),
                readLong(input, "end", -1),
                readLong(input, "duration", -1),
                readLong(input, "now", 0),
            ),
            "fontPercent" to fontPercent(readLong(input, "fontPercent", 100)),
            "preview" to previewText(readString(input, "text")),
        )
    }

    /** 概览大卡：连接状态文案 + 三个指标。 */
    fun statusView(input: Map<String, Any?>): Map<String, Any?> {
        val connected = input["connected"] as? Boolean ?: false
        val paused = input["paused"] as? Boolean ?: false
        val calls = readLong(input, "calls", -1)
        val total = readLong(input, "totalTokens", -1)
        val hit = readDouble(input, "cacheHitRate", -1.0)
        val unit = readString(input, "tokenUnit").ifEmpty { "auto" }
        return linkedMapOf(
            "connectionLabel" to if (connected) "控制台已连接" else "控制台未连接",
            "botLabel" to when {
                connected && !paused -> "DSH 运行中"
                paused -> "自动回复已暂停"
                else -> "DSH 未运行"
            },
            "calls" to count(calls),
            "totalTokens" to tokenCountIn(total, unit),
            "hitRate" to percent(hit),
            "accent" to when {
                connected && !paused -> "ok"
                paused -> "warn"
                else -> "idle"
            },
        )
    }

    // ---------------------------------------------------------------- 分发

    /**
     * MethodChannel 入口。方法名与原 FFI 符号一一对应，
     * 失败时抛 [RuleException]，Dart 侧统一转成 `CoreException`。
     */
    fun handle(method: String, arguments: Any?): Any? = when (method) {
        "version" -> linkedMapOf("name" to NAME, "version" to VERSION)
        "origin" -> origin(arguments as? String ?: "")
        "describe" -> describe(asMap(arguments))
        "statusView" -> statusView(asMap(arguments))
        "previews" -> {
            val items = (asMap(arguments)["items"] as? List<*>) ?: emptyList<Any?>()
            items.map { previewText(it as? String ?: "") }
        }
        // 下面是逐条规则的直通口，只为与 Rust 参考实现（rust/src/lib.rs 的
        // dispatch）对齐、并让 GoldenParityTest 能逐条比对而存在；
        // 界面走的是上面的 describe/statusView 组合口。
        "fontPercent" -> fontPercent(readLong(asMap(arguments), "value", 100))
        "count" -> count(readLong(asMap(arguments), "value", -1))
        "tokenCount" -> tokenCountIn(
            readLong(asMap(arguments), "value", -1),
            readString(asMap(arguments), "unit").ifEmpty { "auto" },
        )
        "percent" -> percent(readDouble(asMap(arguments), "value", -1.0))
        "elapsed" -> elapsed(readLong(asMap(arguments), "value", -1))
        "compactElapsed" -> compactElapsed(readLong(asMap(arguments), "value", -1))
        "toolTiming" -> {
            val map = asMap(arguments)
            toolTiming(
                readString(map, "outcome"),
                readLong(map, "start", -1),
                readLong(map, "end", -1),
                readLong(map, "duration", -1),
                readLong(map, "now", 0),
            )
        }
        "profileName" -> {
            val map = asMap(arguments)
            profileName(readString(map, "input"), readString(map, "fallback"))
        }
        "chatTitle" -> {
            val map = asMap(arguments)
            chatTitle(readString(map, "key"), readString(map, "name"))
        }
        "statusLabel" -> statusLabel(readString(asMap(arguments), "value"))
        "previewText" -> previewText(readString(asMap(arguments), "value"))
        else -> throw RuleException("未知的规则方法：$method")
    }

    @Suppress("UNCHECKED_CAST")
    private fun asMap(value: Any?): Map<String, Any?> =
        (value as? Map<String, Any?>) ?: emptyMap()

    private fun readString(map: Map<String, Any?>, key: String): String =
        map[key] as? String ?: ""

    private fun readLong(map: Map<String, Any?>, key: String, fallback: Long): Long =
        when (val raw = map[key]) {
            is Int -> raw.toLong()
            is Long -> raw
            is Double -> raw.toLong()
            is Number -> raw.toLong()
            else -> fallback
        }

    private fun readDouble(map: Map<String, Any?>, key: String, fallback: Double): Double =
        when (val raw = map[key]) {
            is Double -> raw
            is Int -> raw.toDouble()
            is Long -> raw.toDouble()
            is Number -> raw.toDouble()
            else -> fallback
        }
}
