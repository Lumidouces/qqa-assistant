#!/usr/bin/env bash
# Build the Rust core for Android and drop the .so where Flutter's Gradle build
# expects prebuilt jniLibs.
#
# The crate is pure Rust, so no C compiler is needed on the host: Android links
# through the NDK clang that ships with the SDK.
#
# Env overrides:
#   NDK        path to the NDK (default: $ANDROID_NDK_HOME, else auto-probe the SDK)
#   API        Android API level (default: 24)
#   TARGET     Rust target triple (default: aarch64-linux-android)
#   ABI_DIR    jniLibs subdirectory (default: arm64-v8a)
#
# Examples:
#   bash tools/build-rust.sh                                        # arm64-v8a
#   TARGET=x86_64-linux-android ABI_DIR=x86_64 bash tools/build-rust.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="${API:-24}"
TARGET="${TARGET:-aarch64-linux-android}"
ABI_DIR="${ABI_DIR:-arm64-v8a}"

# --- locate the NDK --------------------------------------------------------
if [ -z "${NDK:-}" ]; then
  if [ -n "${ANDROID_NDK_HOME:-}" ]; then
    NDK="$ANDROID_NDK_HOME"
  else
    # Probe the usual SDK layouts, newest NDK first.
    for base in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" \
                "$HOME/Android/Sdk" "$LOCALAPPDATA/Android/Sdk" \
                "$HOME/Library/Android/sdk"; do
      [ -n "$base" ] && [ -d "$base/ndk" ] || continue
      NDK="$(find "$base/ndk" -maxdepth 1 -mindepth 1 -type d | sort -r | head -1)"
      [ -n "$NDK" ] && break
    done
  fi
fi
[ -n "${NDK:-}" ] && [ -d "$NDK" ] || {
  echo "NDK not found. Set ANDROID_NDK_HOME or pass NDK=/path/to/ndk." >&2
  exit 1
}

# --- map the Rust target onto the NDK clang name ---------------------------
case "$TARGET" in
  aarch64-linux-android)   CLANG_PREFIX="aarch64-linux-android" ;;
  armv7-linux-androideabi) CLANG_PREFIX="armv7a-linux-androideabi" ;;
  x86_64-linux-android)    CLANG_PREFIX="x86_64-linux-android" ;;
  i686-linux-android)      CLANG_PREFIX="i686-linux-android" ;;
  *) echo "unsupported TARGET: $TARGET" >&2; exit 1 ;;
esac

# Host tag differs per platform; the clang binary may be .cmd on Windows.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) HOST_TAG="windows-x86_64" ;;
  Darwin)               HOST_TAG="darwin-x86_64" ;;
  *)                    HOST_TAG="linux-x86_64" ;;
esac

CLANG=""
for ext in "" ".cmd" ".exe"; do
  candidate="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/${CLANG_PREFIX}${API}-clang${ext}"
  if [ -f "$candidate" ]; then CLANG="$candidate"; break; fi
done
[ -n "$CLANG" ] || { echo "missing NDK clang under $NDK (host tag $HOST_TAG)" >&2; exit 1; }

AR="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/llvm-ar"
[ -f "$AR.exe" ] && AR="$AR.exe"
[ -f "$AR" ] || { echo "missing llvm-ar under $NDK" >&2; exit 1; }

# --- build -----------------------------------------------------------------
# Cargo env var names use underscores, not dashes.
TARGET_ENV="$(echo "$TARGET" | tr '-' '_')"
TARGET_UPPER="$(echo "$TARGET" | tr 'a-z-' 'A-Z_')"
export "CARGO_TARGET_${TARGET_UPPER}_LINKER=$CLANG"
export "CC_${TARGET_ENV}=$CLANG"
export "AR_${TARGET_ENV}=$AR"

cd "$ROOT/rust"
cargo build --release --target "$TARGET"

SRC="$ROOT/rust/target/$TARGET/release/libqqa_core.so"
OUT="$ROOT/android/app/src/main/jniLibs/$ABI_DIR"
mkdir -p "$OUT"
cp "$SRC" "$OUT/libqqa_core.so"
ls -l "$OUT/libqqa_core.so"
