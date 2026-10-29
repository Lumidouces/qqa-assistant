#!/usr/bin/env bash
# 上传/发布前必须跑一遍：确认 APK 里装的是手机能用的 ABI。
#
# 背景：build.gradle.kts 的 resolvedAbi 曾经把 `android-arm,android-arm64,android-x64`
# 这个胖串里的 android-x64 判赢，于是 `flutter build apk --release` 打出来的是
# x86_64-only 的包 —— 装到真机上会直接报「该应用与64位系统不兼容」。
#
# 用法：bash tools/check-apk-abi.sh dist/xxx.apk [期望ABI]
#       默认期望 arm64-v8a

set -u
APK="${1:?用法: bash tools/check-apk-abi.sh <apk> [期望ABI]}"
WANT="${2:-arm64-v8a}"

echo "检查 $APK"
ABIS=$(unzip -l "$APK" | grep -oE 'lib/[a-z0-9_-]+/' | sed 's#lib/##;s#/##' | sort -u)
echo "  包含 ABI: $(echo $ABIS | tr '\n' ' ')"

fail=0
if [ -z "$ABIS" ]; then
  echo "  ✗ 包里没有任何 native lib，装上去会崩" >&2
  fail=1
fi
for a in $ABIS; do
  if [ "$a" != "$WANT" ]; then
    echo "  ✗ 多余的 ABI: $a（期望只有 $WANT）" >&2
    fail=1
  fi
done
if ! echo "$ABIS" | grep -qx "$WANT"; then
  echo "  ✗ 缺少期望的 ABI: $WANT" >&2
  fail=1
fi

# libqqa_core.so 的 ELF machine 必须和目录名对上（183=aarch64, 62=x86_64）
tmp=$(mktemp -d)
for a in $ABIS; do
  unzip -o -q "$APK" "lib/$a/libqqa_core.so" -d "$tmp" 2>/dev/null || continue
  m=$("${PYTHON:-python}" - "$tmp/lib/$a/libqqa_core.so" <<'PY'
import struct,sys
d=open(sys.argv[1],'rb').read(20)
print(struct.unpack('<H',d[18:20])[0])
PY
)
  case "$a:$m" in
    arm64-v8a:183|armeabi-v7a:40|x86_64:62|x86:3) echo "  ✓ $a ELF machine=$m 正确";;
    *) echo "  ✗ $a 的 libqqa_core.so machine=$m 不匹配（打错了架构）" >&2; fail=1;;
  esac
done
rm -rf "$tmp"

if [ "$fail" -ne 0 ]; then
  echo "ABI 检查失败，不要发布这个包" >&2
  exit 1
fi
echo "ABI 检查通过：$WANT"
