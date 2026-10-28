//! C ABI bridge used by the Flutter side through `dart:ffi`.
//!
//! Every entry point takes and returns UTF-8 C strings. Results are JSON
//! documents so the Dart layer can decode one shape for success and failure:
//!
//! ```json
//! {"ok": true, "data": ...}
//! {"ok": false, "error": "..."}
//! ```
//!
//! Strings handed back to Dart are allocated with `CString::into_raw`; Dart must
//! return them through [`qqa_string_free`].

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
    envelope(Ok(json!({
        "name": "qqa_core",
        "version": env!("CARGO_PKG_VERSION"),
    })))
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
/// `input` is a JSON object with the raw fields the cards need; the reply has
/// every label already formatted so the Dart side only lays widgets out.
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
    let data = json!({
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
    });
    envelope(Ok(data))
}

/// Batch preview formatter: input is `{"items":["raw","raw"]}`, reply is a list
/// of already-collapsed previews. Keeps the session list rendering in one FFI hop.
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
    let items = parsed
        .get("items")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let out: Vec<String> = items
        .iter()
        .map(|item| rules::preview_text(item.as_str().unwrap_or("")))
        .collect();
    envelope(Ok(Value::Array(
        out.into_iter().map(Value::String).collect(),
    )))
}

/// Describe a status payload in one call: connection state text, metric labels
/// and the usage card numbers, all formatted by the shared Rust rules.
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

    envelope(Ok(json!({
        "connectionLabel": if connected { "控制台已连接" } else { "控制台未连接" },
        "botLabel": if connected && !paused { "DSH 运行中" } else if paused { "自动回复已暂停" } else { "DSH 未运行" },
        "calls": rules::count(calls),
        "totalTokens": rules::token_count_in(total, token_unit),
        "hitRate": rules::percent(hit),
        "accent": if connected && !paused { "ok" } else if paused { "warn" } else { "idle" },
    })))
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
}
