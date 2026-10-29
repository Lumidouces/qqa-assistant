#!/usr/bin/env bash
# Build the Rust core for Android and drop the .so where Flutter's Gradle build
# expects prebuilt jniLibs.
#
# Toolchain lives on E: (installed earlier); nothing here needs a C compiler on
# the host because the crate is pure Rust and Android links through NDK clang.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NDK="${NDK:-/e/toolchains/android-sdk/ndk/27.0.12077973}"
API="${API:-24}"
TARGET="${TARGET:-aarch64-linux-android}"
ABI_DIR="${ABI_DIR:-arm64-v8a}"

HOST_TAG="windows-x86_64"
CLANG="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/aarch64-linux-android${API}-clang.cmd"
[ -f "$CLANG" ] || CLANG="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/aarch64-linux-android${API}-clang.exe"
[ -f "$CLANG" ] || { echo "missing NDK clang under $NDK" >&2; exit 1; }

export PATH="/e/toolchains/cargo/bin:$PATH"
export RUSTUP_HOME=/e/toolchains/rustup
export CARGO_HOME=/e/toolchains/cargo
export TMP="$ROOT/.tmp"
export TEMP="$ROOT/.tmp"
mkdir -p "$TMP"

export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$CLANG"
export CC_aarch64_linux_android="$CLANG"
export AR_aarch64_linux_android="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/llvm-ar.exe"

cd "$ROOT/rust"
cargo build --release --target "$TARGET" --offline

SRC="$ROOT/rust/target/$TARGET/release/libqqa_core.so"
OUT="$ROOT/android/app/src/main/jniLibs/$ABI_DIR"
mkdir -p "$OUT"
cp "$SRC" "$OUT/libqqa_core.so"
ls -l "$OUT/libqqa_core.so"
