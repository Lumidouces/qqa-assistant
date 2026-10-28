//! Pure presentation / normalization rules.
//!
//! Direct port of the original `AppRules.java` so the Flutter UI shows exactly
//! the same labels and numbers as the Java app did.

/// Clamp the font scale to 85%..160%, like `AppRules.fontPercent`.
pub fn font_percent(value: i64) -> i64 {
    value.clamp(85, 160)
}

/// Normalize a user typed address into a bare `https://host[:port]` origin.
///
/// Rejects anything that is not a plain HTTPS root: credentials, query string,
/// fragment, or a non-root path all fail. Port 443 (and the absence of a port)
/// collapses away.
pub fn origin(input: &str) -> Result<String, String> {
    let trimmed = input.trim();
    let err = || "请填写完整 HTTPS 根地址，不含账号密码、路径、参数或 # 标记".to_string();
    if trimmed.is_empty() {
        return Err(err());
    }

    // Split off scheme.
    let (scheme, rest) = match trimmed.split_once("://") {
        Some(parts) => parts,
        None => return Err(err()),
    };
    if !scheme.eq_ignore_ascii_case("https") {
        return Err(err());
    }
    if rest.contains('#') || rest.contains('?') {
        return Err(err());
    }
    let (authority, path) = match rest.find('/') {
        Some(index) => (&rest[..index], &rest[index..]),
        None => (rest, ""),
    };
    if !path.is_empty() && path != "/" {
        return Err(err());
    }
    if authority.is_empty() || authority.contains('@') {
        return Err(err());
    }

    // Separate host and optional port. IPv6 literals keep their brackets.
    let (host, port) = if let Some(stripped) = authority.strip_prefix('[') {
        let close = stripped.find(']').ok_or_else(err)?;
        let host = &stripped[..close];
        let tail = &stripped[close + 1..];
        let port = match tail.strip_prefix(':') {
            Some(text) => Some(text.parse::<u32>().map_err(|_| err())?),
            None if tail.is_empty() => None,
            None => return Err(err()),
        };
        (host.to_string(), port)
    } else {
        match authority.rsplit_once(':') {
            Some((host, text)) => {
                let port = text.parse::<u32>().map_err(|_| err())?;
                (host.to_string(), Some(port))
            }
            None => (authority.to_string(), None),
        }
    };

    if host.is_empty() || host.contains(' ') {
        return Err(err());
    }
    if let Some(value) = port {
        if value == 0 || value > 65535 {
            return Err(err());
        }
    }

    let lower = host.to_ascii_lowercase();
    let bracketed = if lower.contains(':') {
        format!("[{lower}]")
    } else {
        lower
    };
    match port {
        None | Some(443) => Ok(format!("https://{bracketed}")),
        Some(value) => Ok(format!("https://{bracketed}:{value}")),
    }
}

/// Truncate a display name to at most 8 code points.
pub fn profile_name(input: &str, fallback: &str) -> String {
    let value = input.trim();
    if value.is_empty() {
        return fallback.to_string();
    }
    let mut out = String::new();
    for (index, ch) in value.chars().enumerate() {
        if index >= 8 {
            break;
        }
        out.push(ch);
    }
    out
}

/// Human title for a chat key (`group:123` / `private:456`).
pub fn chat_title(key: &str, name: &str) -> String {
    let trimmed = name.trim();
    if !trimmed.is_empty() {
        return trimmed.to_string();
    }
    if let Some(rest) = key.strip_prefix("group:") {
        return format!("群聊 {rest}");
    }
    if let Some(rest) = key.strip_prefix("private:") {
        return format!("私聊 {rest}");
    }
    if key.is_empty() {
        "未命名会话".to_string()
    } else {
        key.to_string()
    }
}

/// Map a raw session status to a Chinese label.
pub fn status_label(status: &str) -> String {
    let label = match status {
        "running" => "处理中",
        "waiting" => "等待中",
        "error" | "failed" => "失败",
        "delivered" => "已回复",
        "completed" | "ended" => "已结束",
        "aborted" | "stopped" => "已停止",
        "noreply" | "skipped" => "未回复",
        "" => "状态未知",
        other => other,
    };
    label.to_string()
}

/// Compact large counters: 1.2万 / 3.4M.
pub fn count(value: i64) -> String {
    if value < 0 {
        return "—".to_string();
    }
    if value >= 1_000_000 {
        return format!("{}M", one_decimal(value as f64 / 1_000_000.0));
    }
    if value >= 10_000 {
        return format!("{}万", one_decimal(value as f64 / 10_000.0));
    }
    value.to_string()
}

/// Round half away from zero, then drop a trailing `.0`.
fn one_decimal(value: f64) -> String {
    let rounded = (value * 10.0).round() / 10.0;
    let text = format!("{rounded:.1}");
    match text.strip_suffix(".0") {
        Some(head) => head.to_string(),
        None => text,
    }
}

/// Token counter formatting used on the usage card.
pub fn token_count(value: i64) -> String {
    if value < 0 {
        return "— tok".to_string();
    }
    if value >= 1000 {
        return format!("{}k tok", one_decimal(value as f64 / 1000.0));
    }
    format!("{value} tok")
}

/// `0.85` -> `85%`; negative / unknown -> `—`.
pub fn percent(value: f64) -> String {
    if !value.is_finite() || value < 0.0 {
        return "—".to_string();
    }
    let clamped = value.clamp(0.0, 1.0);
    format!("{}%", (clamped * 100.0).round() as i64)
}

/// Collapse CQ codes in a trigger preview into readable text.
pub fn preview_text(value: &str) -> String {
    if value.is_empty() {
        return String::new();
    }
    let mut out = String::with_capacity(value.len());
    let bytes: Vec<char> = value.chars().collect();
    let mut index = 0usize;
    while index < bytes.len() {
        if bytes[index] == '[' && value[char_byte_index(&bytes, index)..].starts_with("[CQ:") {
            if let Some(end) = find_cq_end(&bytes, index) {
                let code: String = bytes[index..end].iter().collect();
                if code.starts_with("[CQ:reply") || code.starts_with("[CQ:at") {
                    if let Some(qq) = code.split("qq=").nth(1) {
                        let qq: String = qq.chars().take_while(|c| c.is_ascii_digit()).collect();
                        if !qq.is_empty() {
                            out.push('@');
                            out.push_str(&qq);
                        }
                    }
                } else if code.starts_with("[CQ:image") {
                    out.push_str("[图片]");
                }
                index = end;
                continue;
            }
        }
        out.push(bytes[index]);
        index += 1;
    }

    let squeezed: String = {
        let mut result = String::with_capacity(out.len());
        let mut last_space = false;
        for ch in out.chars() {
            if ch.is_whitespace() {
                if !last_space {
                    result.push(' ');
                }
                last_space = true;
            } else {
                result.push(ch);
                last_space = false;
            }
        }
        result.trim().to_string()
    };

    if squeezed.chars().count() > 240 {
        let head: String = squeezed.chars().take(240).collect();
        return format!("{head}…");
    }
    squeezed
}

fn char_byte_index(chars: &[char], index: usize) -> usize {
    chars[..index].iter().map(|c| c.len_utf8()).sum()
}

fn find_cq_end(chars: &[char], start: usize) -> Option<usize> {
    let mut index = start;
    while index < chars.len() {
        if chars[index] == ']' {
            return Some(index + 1);
        }
        index += 1;
    }
    None
}

/// `12.3 秒` / `3分20秒` / `1时5分`.
pub fn elapsed(ms: i64) -> String {
    if ms < 0 {
        return "未知".to_string();
    }
    if ms < 60_000 {
        return format!("{:.1} 秒", ms as f64 / 1000.0);
    }
    if ms < 3_600_000 {
        return format!("{}分{}秒", ms / 60_000, (ms % 60_000) / 1000);
    }
    format!("{}时{}分", ms / 3_600_000, (ms % 3_600_000) / 60_000)
}

/// `1.4s` / `2m10s` / `1h4m`.
pub fn compact_elapsed(ms: i64) -> String {
    if ms < 0 {
        return "用时未知".to_string();
    }
    if ms < 60_000 {
        let text = format!("{:.1}", ms as f64 / 1000.0);
        return format!("{}s", text.trim_end_matches(".0"));
    }
    if ms < 3_600_000 {
        return format!("{}m{}s", ms / 60_000, (ms % 60_000) / 1000);
    }
    format!("{}h{}m", ms / 3_600_000, (ms % 3_600_000) / 60_000)
}

/// Format a tool call duration with its outcome suffix.
pub fn tool_timing(outcome: &str, start: i64, end: i64, duration: i64, now: i64) -> String {
    if outcome == "running" {
        return if start >= 0 {
            format!("运行中 {}", compact_elapsed((now - start).max(0)))
        } else {
            "运行中".to_string()
        };
    }
    let elapsed_ms = if duration >= 0 {
        duration
    } else if start >= 0 && end >= start {
        end - start
    } else {
        -1
    };
    let mut label = if elapsed_ms >= 0 {
        compact_elapsed(elapsed_ms)
    } else {
        "用时未提供".to_string()
    };
    match outcome {
        "error" => label.push_str("（失败）"),
        "timeout" => label.push_str("（超时）"),
        "ok" | "" => {}
        _ => label.push_str("（状态未知）"),
    }
    label
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn origin_accepts_plain_https() {
        assert_eq!(origin("https://a.example").unwrap(), "https://a.example");
        assert_eq!(origin("HTTPS://A.Example/").unwrap(), "https://a.example");
        assert_eq!(origin("https://a.example:8443").unwrap(), "https://a.example:8443");
        assert_eq!(origin("https://a.example:443").unwrap(), "https://a.example");
    }

    #[test]
    fn origin_rejects_bad_input() {
        assert!(origin("http://a.example").is_err());
        assert!(origin("https://a.example/api").is_err());
        assert!(origin("https://a.example?x=1").is_err());
        assert!(origin("https://user:pw@a.example").is_err());
        assert!(origin("https://a.example#f").is_err());
        assert!(origin("").is_err());
    }

    #[test]
    fn counters_and_labels() {
        assert_eq!(count(119), "119");
        assert_eq!(count(11_500), "1.2万");
        assert_eq!(count(3_100_000), "3.1M");
        assert_eq!(count(-1), "—");
        assert_eq!(status_label("running"), "处理中");
        assert_eq!(status_label("weird"), "weird");
        assert_eq!(font_percent(10), 85);
        assert_eq!(font_percent(999), 160);
    }

    #[test]
    fn preview_strips_cq_and_squeezes_space() {
        assert_eq!(preview_text("[CQ:at,qq=1234]  hi   there"), "@1234 hi there");
        assert_eq!(preview_text("[CQ:image,file=x.jpg]看一下"), "[图片]看一下");
        assert_eq!(preview_text("[CQ:reply,id=9]正文"), "正文");
    }

    #[test]
    fn timings() {
        assert_eq!(elapsed(1500), "1.5 秒");
        assert_eq!(elapsed(200_000), "3分20秒");
        assert_eq!(compact_elapsed(1400), "1.4s");
        assert_eq!(tool_timing("error", 0, 1200, -1, 0), "1.2s（失败）");
    }

    #[test]
    fn titles() {
        assert_eq!(chat_title("group:42", ""), "群聊 42");
        assert_eq!(chat_title("private:7", "小明"), "小明");
        assert_eq!(profile_name("一二三四五六七八九十", "账号1"), "一二三四五六七八");
    }
}
