package cn.local.qqa.qqa_assistant

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * 规则内核回归测试。
 *
 * 每条断言都直接抄自 `rust/src/rules.rs` 的 `#[test]`（同一输入 → 同一字符串），
 * 所以这套 JVM 测试同时充当「Kotlin 移植是否与 Rust 原版等价」的守门人。
 */
class QqaCoreTest {

    // ---------------------------------------------------------- token 单位阶梯

    @Test
    fun tokenCountScalesByIntuition() {
        assertEquals("999 tok", QqaCore.tokenCount(999))
        assertEquals("13.1k tok", QqaCore.tokenCount(13_146))
        assertEquals("456k tok", QqaCore.tokenCount(456_000))
        assertEquals("13.1M tok", QqaCore.tokenCount(13_146_300))
        assertEquals("13.1B tok", QqaCore.tokenCount(13_146_300_000))
        // 点数字切换档位：M 档不再往上进 B，k 档连 M 都不进。
        assertEquals("13146.3M tok", QqaCore.tokenCountIn(13_146_300_000, "m"))
        assertEquals("13146.3k tok", QqaCore.tokenCountIn(13_146_300, "k"))
        assertEquals("— tok", QqaCore.tokenCountIn(-1, "m"))
    }

    // -------------------------------------------------------------- 地址归一化

    @Test
    fun originAcceptsPlainHttps() {
        assertEquals("https://a.example", QqaCore.origin("https://a.example"))
        assertEquals("https://a.example", QqaCore.origin("HTTPS://A.Example/"))
        assertEquals("https://a.example:8443", QqaCore.origin("https://a.example:8443"))
        assertEquals("https://a.example", QqaCore.origin("https://a.example:443"))
    }

    @Test
    fun originRejectsBadInput() {
        val bad = listOf(
            "http://a.example",
            "https://a.example/api",
            "https://a.example?x=1",
            "https://user:pw@a.example",
            "https://a.example#f",
            "",
        )
        for (input in bad) {
            try {
                QqaCore.origin(input)
                fail("应当拒绝：$input")
            } catch (_: QqaCore.RuleException) {
                // 预期
            }
        }
    }

    @Test
    fun sameOriginComparesNormalizedRoots() {
        assertTrue(QqaCore.sameOrigin("https://a.example", "https://A.example/x?y=1"))
        assertFalse(QqaCore.sameOrigin("https://a.example", "https://b.example/x"))
    }

    // -------------------------------------------------------------- 计数与标签

    @Test
    fun countersAndLabels() {
        assertEquals("119", QqaCore.count(119))
        assertEquals("1.2万", QqaCore.count(11_500))
        assertEquals("3.1M", QqaCore.count(3_100_000))
        assertEquals("—", QqaCore.count(-1))
        assertEquals("处理中", QqaCore.statusLabel("running"))
        assertEquals("weird", QqaCore.statusLabel("weird"))
        assertEquals(85L, QqaCore.fontPercent(10))
        assertEquals(160L, QqaCore.fontPercent(999))
        assertEquals("85%", QqaCore.percent(0.85))
        assertEquals("—", QqaCore.percent(-0.2))
    }

    // ---------------------------------------------------------------- 预览折叠

    @Test
    fun previewStripsCqAndSqueezesSpace() {
        assertEquals("@1234 hi there", QqaCore.previewText("[CQ:at,qq=1234]  hi   there"))
        assertEquals("[图片]看一下", QqaCore.previewText("[CQ:image,file=x.jpg]看一下"))
        assertEquals("正文", QqaCore.previewText("[CQ:reply,id=9]正文"))
        assertEquals("", QqaCore.previewText(""))
    }

    // ------------------------------------------------------------------- 时间

    @Test
    fun timings() {
        assertEquals("1.5 秒", QqaCore.elapsed(1_500))
        assertEquals("3分20秒", QqaCore.elapsed(200_000))
        assertEquals("1.4s", QqaCore.compactElapsed(1_400))
        assertEquals("1.2s（失败）", QqaCore.toolTiming("error", 0, 1_200, -1, 0))
        // Rust: compact_elapsed 用 {:.1} 再 trim_end_matches(".0") → 2000ms 是 "2s"
        assertEquals("运行中 2s", QqaCore.toolTiming("running", 0, -1, -1, 2_000))
        assertEquals("用时未知", QqaCore.compactElapsed(-1))
    }

    // ------------------------------------------------------------------- 标题

    @Test
    fun titles() {
        assertEquals("群聊 42", QqaCore.chatTitle("group:42", ""))
        assertEquals("小明", QqaCore.chatTitle("private:7", "小明"))
        assertEquals("未命名会话", QqaCore.chatTitle("", ""))
        assertEquals("一二三四五六七八", QqaCore.profileName("一二三四五六七八九十", "账号1"))
        assertEquals("账号1", QqaCore.profileName("   ", "账号1"))
    }

    // -------------------------------------------------------------- 复合视图

    @Test
    fun describeFormatsASnapshot() {
        val data = QqaCore.describe(
            mapOf(
                "status" to "running",
                "chatKey" to "group:42",
                "chatName" to "",
                "calls" to 11500,
                "tokens" to 310000,
                "totalTokens" to 45600,
                "elapsedMs" to 200000,
                "outcome" to "error",
                "start" to 0,
                "end" to 1200,
                "duration" to -1,
                "now" to 0,
                "fontPercent" to 999,
                "text" to "[CQ:at,qq=7]  hi",
            )
        )
        assertEquals("处理中", data["statusLabel"])
        assertEquals("群聊 42", data["chatTitle"])
        assertEquals("1.2万", data["calls"])
        assertEquals(160L, data["fontPercent"])
        assertEquals("@7 hi", data["preview"])
    }

    @Test
    fun statusViewLabels() {
        val online = QqaCore.statusView(
            mapOf(
                "connected" to true,
                "paused" to false,
                "calls" to 119,
                "totalTokens" to 310000,
                "cacheHitRate" to 0.85,
            )
        )
        assertEquals("控制台已连接", online["connectionLabel"])
        assertEquals("DSH 运行中", online["botLabel"])
        assertEquals("85%", online["hitRate"])
        assertEquals("ok", online["accent"])

        val paused = QqaCore.statusView(
            mapOf("connected" to true, "paused" to true)
        )
        assertEquals("自动回复已暂停", paused["botLabel"])
        assertEquals("warn", paused["accent"])
    }

    @Test
    fun handleDispatchesByMethodName() {
        assertEquals("https://a.example", QqaCore.handle("origin", "https://a.example"))
        val version = QqaCore.handle("version", null) as Map<*, *>
        assertEquals("qqa_core", version["name"])
        val previews = QqaCore.handle(
            "previews",
            mapOf("items" to listOf("[CQ:image,file=a.jpg]x", "  y  z ")),
        ) as List<*>
        assertEquals("[图片]x", previews[0])
        assertEquals("y z", previews[1])
    }
}
