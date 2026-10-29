//! C ABI bridge plus channel-shaped dispatch for the QQA rules kernel.
//!
//! This crate is kept **in the tree as the reference implementation** of the
//! presentation rules. The shipping Android build uses the Kotlin mirror
//! (`android/app/src/main/kotlin/cn/local/qqa/qqa_assistant/QqaCore.kt`); the
//! two are held in lockstep by `android/app/src/test/resources/golden.json`,
//! which is generated here by `cargo run --bin golden` and asserted against the
//! Kotlin kernel in `GoldenParityTest`.
//!
//! The C ABI entries take and return UTF-8 C strings whose payload is a JSON
//! document so a single shape covers success and failure:
//!
//! ```json
//! {"ok": true, "data": ...}
//! {"ok": false, "error": "..."}
//! ```
//!
//! Strings handed back to the caller are allocated with `CString::into_raw`;
//! they must be returned through [`qqa_string_free`].

mod rules;

use serde_json::{json, Value};
use std::ffi::{c_char, CStr, CString};

fn to_c_string(value: String) -> *mut c_char {
    // Interior NULs cannot survive CString; strip them so this can never panic.
    let cleaned = value.replace('\0', "");
    match CString::new(cleaned) {
        Ok(text) => text.into_raw(),
        Err(_) => CString::new("{\"ok\":false,\"error\":\"internal\"}")
            .expect("static")
            .into_raw(),
    }
}

fn envelope(result: Result<Value, String>) -> *mut c_char {
    let payload = match result {
        Ok(data) => json!({ "ok": true, "data": data }),
        Err(error) => json!({ "ok": false, "error": error }),
    };
    to_c_string(payload.to_string())
}

/// # Safety
/// `ptr` must be a valid NUL-terminated UTF-8 string or null.
unsafe fn take_string(ptr: *const c_char) -> String {
    if ptr.is_null() {
        return String::new();
    }
    CStr::from_ptr(ptr).to_string_lossy().into_owned()
}

/// Free a string previously returned by this library.
///
/// # Safety
/// `ptr` must come from one of the functions below and must not be freed twice.
#[no_mangle]
pub unsafe extern "C" fn qqa_string_free(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(CString::from_raw(ptr));
    }
}

/// Version banner, so the Dart side can prove the native library really loaded.
///
/// # Safety
/// Always safe to call; ignores its argument.
#[no_mangle]
pub unsafe extern "C" fn qqa_version(_unused: *const c_char) -> *mut c_char {
    envelope(Ok(version_payload()))
}

/// Normalize a user typed address; returns `{"ok":true,"data":"https://host"}`.
///
/// # Safety
/// `input` must be a valid NUL-terminated string or null.
#[no_mangle]
pub unsafe extern "C" fn qqa_origin(input: *const c_char) -> *mut c_char {
    envelope(rules::origin(&take_string(input)).map(Value::String))
}

/// Full presentation rules bundle for one snapshot, computed in Rust.
///
/// # Safety
/// `input` must be a valid NUL-terminated string or null.
#[no_mangle]
pub unsafe extern "C" fn qqa_describe(input: *const c_char) -> *mut c_char {
    let text = take_string(input);
    let parsed: Value = match serde_json::from_str(&text) {
        Ok(value) => value,
        Err(error) => return envelope(Err(format!("输入无法解析：{error}"))),
    };
    envelope(describe_payload(&parsed))
}

/// Batch preview formatter: input is `{"items":["raw","raw"]}`.
///
/// # Safety
/// `input` must be a valid NUL-terminated string or null.
#[no_mangle]
pub unsafe extern "C" fn qqa_previews(input: *const c_char) -> *mut c_char {
    let text = take_string(input);
    let parsed: Value = match serde_json::from_str(&text) {
        Ok(value) => value,
        Err(error) => return envelope(Err(format!("输入无法解析：{error}"))),
    };
    envelope(Ok(previews_payload(&parsed)))
}

/// Status payload description: connection text, metric labels, usage numbers.
///
/// # Safety
/// `input` must be a valid NUL-terminated string or null.
#[no_mangle]
pub unsafe extern "C" fn qqa_status_view(input: *const c_char) -> *mut c_char {
    let text = take_string(input);
    let parsed: Value = match serde_json::from_str(&text) {
        Ok(value) => value,
        Err(error) => return envelope(Err(format!("输入无法解析：{error}"))),
    };
    envelope(Ok(status_view_payload(&parsed)))
}

// ---------------------------------------------------------------------------
// Payload builders
//
// Kept out of the `extern "C"` entries so `dispatch` (and therefore the golden
// generator) exercises byte-for-byte the same code the C ABI returns.
// ---------------------------------------------------------------------------

fn version_payload() -> Value {
    json!({
        "name": "qqa_core",
        "version": env!("CARGO_PKG_VERSION"),
    })
}

fn describe_payload(parsed: &Value) -> Result<Value, String> {
    let read_str = |key: &str| -> String {
        parsed
            .get(key)
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string()
    };
    let read_i64 = |key: &str, fallback: i64| -> i64 {
        parsed.get(key).and_then(Value::as_i64).unwrap_or(fallback)
    };

    let status_code = read_str("status");
    let token_unit = read_str("tokenUnit");
    Ok(json!({
        "statusLabel": rules::status_label(&status_code),
        "chatTitle": rules::chat_title(&read_str("chatKey"), &read_str("chatName")),
        "profileName": rules::profile_name(&read_str("profile"), &read_str("fallback")),
        "calls": rules::count(read_i64("calls", -1)),
        "tokens": rules::token_count_in(read_i64("tokens", -1), &token_unit),
        "totalTokens": rules::token_count_in(read_i64("totalTokens", -1), &token_unit),
        "promptTokens": rules::token_count_in(read_i64("promptTokens", -1), &token_unit),
        "completionTokens": rules::token_count_in(read_i64("completionTokens", -1), &token_unit),
        "cacheReadTokens": rules::token_count_in(read_i64("cacheReadTokens", -1), &token_unit),
        "elapsed": rules::elapsed(read_i64("elapsedMs", -1)),
        "compactElapsed": rules::compact_elapsed(read_i64("elapsedMs", -1)),
        "toolTiming": rules::tool_timing(
            &read_str("outcome"),
            read_i64("start", -1),
            read_i64("end", -1),
            read_i64("duration", -1),
            read_i64("now", 0),
        ),
        "fontPercent": rules::font_percent(read_i64("fontPercent", 100)),
        "preview": rules::preview_text(&read_str("text")),
    }))
}

fn previews_payload(parsed: &Value) -> Value {
    let items = parsed
        .get("items")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let out: Vec<String> = items
        .iter()
        .map(|item| rules::preview_text(item.as_str().unwrap_or("")))
        .collect();
    Value::Array(out.into_iter().map(Value::String).collect())
}

fn status_view_payload(parsed: &Value) -> Value {
    let connected = parsed
        .get("connected")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let paused = parsed.get("paused").and_then(Value::as_bool).unwrap_or(false);
    let calls = parsed.get("calls").and_then(Value::as_i64).unwrap_or(-1);
    let total = parsed.get("totalTokens").and_then(Value::as_i64).unwrap_or(-1);
    let hit = parsed
        .get("cacheHitRate")
        .and_then(Value::as_f64)
        .unwrap_or(-1.0);
    let token_unit = parsed
        .get("tokenUnit")
        .and_then(Value::as_str)
        .unwrap_or("auto");

    json!({
        "connectionLabel": if connected { "控制台已连接" } else { "控制台未连接" },
        "botLabel": if connected && !paused { "DSH 运行中" } else if paused { "自动回复已暂停" } else { "DSH 未运行" },
        "calls": rules::count(calls),
        "totalTokens": rules::token_count_in(total, token_unit),
        "hitRate": rules::percent(hit),
        "accent": if connected && !paused { "ok" } else if paused { "warn" } else { "idle" },
    })
}

// ---------------------------------------------------------------------------
// Channel-shaped dispatch
//
// One method name per entry the Kotlin `QqaCore.handle` understands, with the
// same argument shapes. `cargo run --bin golden` walks this table to emit the
// parity vectors the Kotlin test replays.
// ---------------------------------------------------------------------------

fn arg_i64(args: &Value, key: &str, fallback: i64) -> i64 {
    args.get(key).and_then(Value::as_i64).unwrap_or(fallback)
}

fn arg_f64(args: &Value, key: &str, fallback: f64) -> f64 {
    args.get(key).and_then(Value::as_f64).unwrap_or(fallback)
}

fn arg_str(args: &Value, key: &str, fallback: &str) -> String {
    args.get(key)
        .and_then(Value::as_str)
        .unwrap_or(fallback)
        .to_string()
}

/// Reference implementation of the rules-channel protocol.
pub fn dispatch(method: &str, args: &Value) -> Result<Value, String> {
    match method {
        "version" => Ok(version_payload()),
        "origin" => rules::origin(args.as_str().unwrap_or("")).map(Value::String),
        "previews" => Ok(previews_payload(args)),
        "describe" => describe_payload(args),
        "statusView" => Ok(status_view_payload(args)),
        "fontPercent" => Ok(json!(rules::font_percent(arg_i64(args, "value", 100)))),
        "count" => Ok(json!(rules::count(arg_i64(args, "value", -1)))),
        "tokenCount" => Ok(json!(rules::token_count_in(
            arg_i64(args, "value", -1),
            &arg_str(args, "unit", "auto"),
        ))),
        "percent" => Ok(json!(rules::percent(arg_f64(args, "value", -1.0)))),
        "elapsed" => Ok(json!(rules::elapsed(arg_i64(args, "value", -1)))),
        "compactElapsed" => Ok(json!(rules::compact_elapsed(arg_i64(
            args, "value", -1
        )))),
        "toolTiming" => Ok(json!(rules::tool_timing(
            &arg_str(args, "outcome", ""),
            arg_i64(args, "start", -1),
            arg_i64(args, "end", -1),
            arg_i64(args, "duration", -1),
            arg_i64(args, "now", 0),
        ))),
        "profileName" => Ok(json!(rules::profile_name(
            &arg_str(args, "input", ""),
            &arg_str(args, "fallback", ""),
        ))),
        "chatTitle" => Ok(json!(rules::chat_title(
            &arg_str(args, "key", ""),
            &arg_str(args, "name", ""),
        ))),
        "statusLabel" => Ok(json!(rules::status_label(&arg_str(args, "value", "")))),
        "previewText" => Ok(json!(rules::preview_text(&arg_str(args, "value", "")))),
        other => Err(format!("未知的规则方法：{other}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn call(f: unsafe extern "C" fn(*const c_char) -> *mut c_char, arg: &str) -> Value {
        let c = CString::new(arg).unwrap();
        let raw = unsafe { f(c.as_ptr()) };
        let text = unsafe { CStr::from_ptr(raw) }.to_string_lossy().into_owned();
        unsafe { qqa_string_free(raw) };
        serde_json::from_str(&text).unwrap()
    }

    #[test]
    fn describe_formats_a_snapshot() {
        let input = r#"{
            "status":"running",
            "chatKey":"group:42",
            "chatName":"",
            "calls":11500,
            "tokens":310000,
            "totalTokens":45600,
            "elapsedMs":200000,
            "outcome":"error",
            "start":0,
            "end":1200,
            "duration":-1,
            "now":0,
            "fontPercent":999,
            "text":"[CQ:at,qq=7]  hi"
        }"#;
        let parsed = call(qqa_describe, input);
        assert_eq!(parsed["ok"], true);
        assert_eq!(parsed["data"]["statusLabel"], "处理中");
        assert_eq!(parsed["data"]["chatTitle"], "群聊 42");
        assert_eq!(parsed["data"]["calls"], "1.2万");
        assert_eq!(parsed["data"]["fontPercent"], 160);
        assert_eq!(parsed["data"]["preview"], "@7 hi");
    }

    #[test]
    fn origin_envelope_reports_errors() {
        let parsed = call(qqa_origin, "http://x");
        assert_eq!(parsed["ok"], false);
    }

    #[test]
    fn previews_batch() {
        let parsed = call(qqa_previews, r#"{"items":["[CQ:image,file=a.jpg]x","  y  z "}])"#);
        assert_eq!(parsed["ok"], false, "trailing junk must be rejected");

        let parsed = call(qqa_previews, r#"{"items":["[CQ:image,file=a.jpg]x"," y  z "]}"#);
        assert_eq!(parsed["data"][0], "[图片]x");
        assert_eq!(parsed["data"][1], "y z");
    }

    #[test]
    fn status_view_labels() {
        let parsed = call(
            qqa_status_view,
            r#"{"connected":true,"paused":false,"calls":119,"totalTokens":310000,"cacheHitRate":0.85}"#,
        );
        assert_eq!(parsed["data"]["connectionLabel"], "控制台已连接");
        assert_eq!(parsed["data"]["botLabel"], "DSH 运行中");
        assert_eq!(parsed["data"]["hitRate"], "85%");

        let parsed = call(qqa_status_view, r#"{"connected":true,"paused":true}"#);
        assert_eq!(parsed["data"]["botLabel"], "自动回复已暂停");
        assert_eq!(parsed["data"]["accent"], "warn");
    }

    #[test]
    fn dispatch_mirrors_the_channel() {
        let hit = dispatch("tokenCount", &json!({"value": 13146353280i64, "unit": "m"})).unwrap();
        assert_eq!(hit, json!("13146.4M tok"));

        let title = dispatch("chatTitle", &json!({"key": "private:7", "name": ""})).unwrap();
        assert_eq!(title, json!("私聊 7"));

        assert!(dispatch("origin", &json!("http://x")).is_err());
        assert_eq!(
            dispatch("nope", &json!(null)).unwrap_err(),
            "未知的规则方法：nope"
        );
    }
}
