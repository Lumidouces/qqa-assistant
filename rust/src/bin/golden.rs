//! Golden-vector generator for the rules kernel.
//!
//! Runs the reference Rust rules over a fixed battery of inputs and writes the
//! results to `android/app/src/test/resources/golden.json`. The Kotlin mirror is
//! then asserted against that file (`GoldenParityTest`), so any behavioural
//! drift between the two implementations fails the Android build.
//!
//! Run with:
//!
//! ```text
//! cargo run --bin golden            # writes the default path
//! cargo run --bin golden -- out.json
//! ```

use qqa_core::dispatch;
use serde_json::{json, Value};
use std::fs;
use std::path::PathBuf;

fn main() {
    let target = std::env::args().nth(1).map(PathBuf::from).unwrap_or_else(|| {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("..")
            .join("android/app/src/test/resources/golden.json")
    });

    let mut out: Vec<Value> = Vec::new();
    let mut cases = 0usize;

    for (method, args) in battery() {
        cases += 1;
        let mut row = serde_json::Map::new();
        row.insert("method".into(), json!(method));
        row.insert("args".into(), args.clone());
        match dispatch(method, &args) {
            Ok(value) => {
                row.insert("expect".into(), value);
            }
            Err(error) => {
                row.insert("error".into(), json!(error));
            }
        }
        out.push(Value::Object(row));
    }

    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent).expect("create resources dir");
    }
    let body = serde_json::to_string_pretty(&Value::Array(out)).expect("serialize");
    fs::write(&target, format!("{body}\n")).expect("write golden.json");
    println!("wrote {} vectors to {}", cases, target.display());
}

fn battery() -> Vec<(&'static str, Value)> {
    let long_text = format!("{}尾巴", "很长".repeat(130));
    let mut cases: Vec<(&'static str, Value)> = Vec::new();

    // ---- version -----------------------------------------------------------
    cases.push(("version", json!(null)));

    // ---- origin ------------------------------------------------------------
    for input in [
        "https://qqa.example.com",
        "https://qqa.example.com/",
        "https://qqa.example.com:443/",
        "  HTTPS://QQA.example.com/app  ",
        "qqa.example.com",
        "https://qqa.example.com:8443/base",
        "http://qqa.example.com",
        "https://user:pw@qqa.example.com",
        "https://qqa.example.com/?a=1",
        "https://qqa.example.com/#frag",
        "",
        "ftp://qqa.example.com",
        "https://[::1]:9000/",
    ] {
        cases.push(("origin", json!(input)));
    }

    // ---- previews ----------------------------------------------------------
    cases.push((
        "previews",
        json!({"items": [
            "[CQ:image,file=a.jpg]看图",
            "[CQ:at,qq=12345] 你好",
            "[CQ:reply,id=9]收到  [CQ:face,id=1]",
            "  y  z ",
            "纯文本没有码",
            ""
        ]}),
    ));
    cases.push(("previews", json!({"items": []})));
    cases.push(("previews", json!({})));

    // ---- count -------------------------------------------------------------
    for value in [-1i64, 0, 1, 999, 1000, 9999, 10_000, 11_500, 12_500, 99_999, 999_999, 1_000_000, 1_234_567] {
        cases.push(("count", json!({"value": value})));
    }

    // ---- tokenCount --------------------------------------------------------
    for (value, unit) in [
        (-1i64, "auto"),
        (0, "auto"),
        (999, "auto"),
        (1_500, "auto"),
        (31_000, "auto"),
        (3_100_000, "auto"),
        (13_146_353_280i64, "auto"),
        (13_146_353_280i64, "m"),
        (13_146_353_280i64, "k"),
        (3_100_000, "b"),
        (2_500, "m"),
        (999, "k"),
        (1_000, "k"),
    ] {
        cases.push(("tokenCount", json!({"value": value, "unit": unit})));
    }

    // ---- percent -----------------------------------------------------------
    for value in [-1.0f64, 0.0, 0.5, 0.85, 1.0, 1.4] {
        cases.push(("percent", json!({"value": value})));
    }

    // ---- elapsed / compactElapsed -----------------------------------------
    for value in [-1i64, 0, 999, 1_500, 59_000, 60_000, 200_000, 3_599_000, 3_600_000, 3_900_000] {
        cases.push(("elapsed", json!({"value": value})));
        cases.push(("compactElapsed", json!({"value": value})));
    }

    // ---- toolTiming --------------------------------------------------------
    for (outcome, start, end, duration, now) in [
        ("running", 0i64, -1i64, -1i64, 2_000i64),
        ("running", -1, -1, -1, -1),
        ("delivered", 0, 1_200, -1, 5_000),
        ("error", 0, 1_200, -1, 0),
        ("timeout", 0, -1, 1_500, 0),
        ("", 0, -1, -1, 0),
    ] {
        cases.push((
            "toolTiming",
            json!({"outcome": outcome, "start": start, "end": end, "duration": duration, "now": now}),
        ));
    }

    // ---- naming / labels ---------------------------------------------------
    for (input, fallback) in [
        ("普淮", ""),
        ("", "默认"),
        ("", ""),
        ("一二三四五六七八九十", ""),
        ("😀😀😀😀😀😀😀😀😀", ""),
    ] {
        cases.push(("profileName", json!({"input": input, "fallback": fallback})));
    }
    for (key, name) in [
        ("group:42", ""),
        ("private:7", ""),
        ("", ""),
        ("", "有名字"),
        ("group:1", "自定义"),
    ] {
        cases.push(("chatTitle", json!({"key": key, "name": name})));
    }
    for value in ["running", "waiting", "error", "failed", "delivered", "completed", "ended", "aborted", "stopped", "noreply", "skipped", "", "别的状态"] {
        cases.push(("statusLabel", json!({"value": value})));
    }

    // ---- previewText -------------------------------------------------------
    for value in [
        "[CQ:at,qq=7]  hi",
        "[CQ:reply,id=3]回复内容",
        "[CQ:image,file=x.png][CQ:image,file=y.png]",
        "  多   个    空格  ",
        long_text.as_str(),
        "",
    ] {
        cases.push(("previewText", json!({"value": value})));
    }

    // ---- describe ----------------------------------------------------------
    cases.push((
        "describe",
        json!({
            "status": "running",
            "chatKey": "group:42",
            "chatName": "",
            "calls": 11500,
            "tokens": 310000,
            "totalTokens": 45600,
            "promptTokens": 20000,
            "completionTokens": 11000,
            "cacheReadTokens": 9000,
            "elapsedMs": 200000,
            "outcome": "error",
            "start": 0,
            "end": 1200,
            "duration": -1,
            "now": 0,
            "fontPercent": 999,
            "text": "[CQ:at,qq=7]  hi"
        }),
    ));
    cases.push((
        "describe",
        json!({"status": "ended", "chatKey": "private:9", "tokenUnit": "m", "totalTokens": 13_146_353_280i64}),
    ));
    cases.push(("describe", json!({})));

    // ---- statusView --------------------------------------------------------
    cases.push((
        "statusView",
        json!({"connected": true, "paused": false, "calls": 119, "totalTokens": 310000, "cacheHitRate": 0.85}),
    ));
    cases.push((
        "statusView",
        json!({"connected": true, "paused": true, "calls": 5, "totalTokens": 1200, "cacheHitRate": 0.5}),
    ));
    cases.push(("statusView", json!({"connected": false})));
    cases.push((
        "statusView",
        json!({"connected": true, "paused": false, "calls": -1, "totalTokens": -1, "cacheHitRate": -1.0, "tokenUnit": "k"}),
    ));

    cases
}
