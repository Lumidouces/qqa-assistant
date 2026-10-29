package cn.local.qqa.qqa_assistant

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * 逐条比对 Kotlin 内核与 Rust 参考实现。
 *
 * `golden.json` 不是手写的：它由 `rust/src/bin/golden.rs` 跑 [QqaCore] 的 Rust 对应物
 * （`qqa_core::dispatch`）逐条算出来 ——
 *
 * ```text
 * cd rust && cargo run --bin golden
 * ```
 *
 * 所以这个测试真正的断言是：同一批输入，两边输出完全一致。任何一边改了格式规则
 * 而另一边没跟上，这里立刻红。
 */
class GoldenParityTest {

    private fun load(): JSONArray {
        val stream = javaClass.classLoader?.getResourceAsStream("golden.json")
            ?: error("测试资源里没有 golden.json；先在 rust/ 下跑 cargo run --bin golden")
        return JSONArray(stream.bufferedReader(Charsets.UTF_8).use { it.readText() })
    }

    @Test
    fun kotlinMatchesRustGoldenVectors() {
        val rows = load()
        assertTrue("黄金向量太少，疑似生成失败", rows.length() >= 100)

        var compared = 0
        for (index in 0 until rows.length()) {
            val row = rows.getJSONObject(index)
            val method = row.getString("method")

            // 版本号两边各自维护（Rust 0.1.0 / Kotlin 1.0.0），不参与比对。
            if (method == "version") continue

            val args = normalize(row.opt("args"))
            if (row.has("error")) {
                val expected = row.getString("error")
                try {
                    QqaCore.handle(method, args)
                    fail("第 $index 条：$method 应当抛错，实际返回了值")
                } catch (error: IllegalArgumentException) {
                    assertEquals("第 $index 条：$method 的错误文案", expected, error.message)
                }
            } else {
                val expected = normalize(row.get("expect"))
                val actual = normalize(QqaCore.handle(method, args))
                assertEquals("第 $index 条：$method（入参 ${row.opt("args")}）", expected, actual)
            }
            compared++
        }

        assertTrue("实际比对了 $compared 条，少于预期", compared >= 100)
    }

    /**
     * 把 JSON（org.json 的对象/数组/数字类型）和 Kotlin 内核的返回值归一成同一套
     * 形状：对象 → Map、数组 → List、整数 → Long、小数 → Double。
     */
    private fun normalize(value: Any?): Any? = when (value) {
        null, JSONObject.NULL -> null
        is JSONObject -> value.keys().asSequence().associateWith { normalize(value.opt(it)) }
        is JSONArray -> (0 until value.length()).map { normalize(value.opt(it)) }
        is Map<*, *> -> value.entries.associate { it.key.toString() to normalize(it.value) }
        is List<*> -> value.map { normalize(it) }
        // org.json 把 0.5 这类小数解析成 BigDecimal，直接 toLong() 会截成 0 —— 必须
        // 先看是不是整数值，再决定用 Long 还是 Double 表达。
        is Number -> {
            val number = value.toDouble()
            val integral = !number.isInfinite() && number == Math.floor(number) && Math.abs(number) < 1e15
            if (integral) number.toLong() else number
        }
        else -> value
    }
}
