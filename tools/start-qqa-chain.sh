#!/usr/bin/env bash
# 一键拉起「手机 → 公网 → 服务器 QQA 控制台」的整条链路。
#
# 链路：
#   手机 → cloudflare 快速隧道 → 本机 13211（改写 Host/Origin）
#        → ssh -L 13210 → 服务器 127.0.0.1:3210（QQA 控制台）
#
# 为什么要改写头：QQA 控制台只信任 Host/Origin == 127.0.0.1:3210 的请求，
# 公网隧道直连一律 403「请求来源不被信任」。
#
# 用法：bash tools/start-qqa-chain.sh
# 停：  pkill -f qqa-proxy.js; pkill -f "13210:127.0.0.1:3210"; pkill -f cf.exe

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NODE="$HOME/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/node/bin/node.exe"
CF="$ROOT/../dsh-remote/bin/cf.exe"
HOST_SSH="Administrator@47.108.210.180"
KEY="$HOME/.ssh/id_ed25519_dsh"

echo "[1/3] ssh 本地转发 13210 -> 服务器 3210"
pkill -f "13210:127.0.0.1:3210" 2>/dev/null
nohup ssh -N -o StrictHostKeyChecking=no -o ServerAliveInterval=20 \
  -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o IdentitiesOnly=yes \
  -i "$KEY" -L 13210:127.0.0.1:3210 "$HOST_SSH" >/tmp/qqa-ssh.log 2>&1 &
sleep 8
curl -s -m 6 -o /dev/null -w "  13210: %{http_code}\n" http://127.0.0.1:13210/api/status

echo "[2/3] 头改写代理 13211 -> 13210"
pkill -f qqa-proxy.js 2>/dev/null
nohup "$NODE" "$ROOT/tools/qqa-proxy.js" >/tmp/qqa-proxy.log 2>&1 &
sleep 3
curl -s -m 6 -o /dev/null -w "  13211: %{http_code}\n" http://127.0.0.1:13211/api/status

echo "[3/3] cloudflare 隧道 -> 13211（域名每次重启都会变）"
pkill -f cf.exe 2>/dev/null
sleep 2
for i in 1 2 3 4 5; do
  nohup "$CF" tunnel --url http://127.0.0.1:13211 --no-autoupdate >/tmp/qqa-cf.log 2>&1 &
  pid=$!
  sleep 30
  url=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/qqa-cf.log | grep -v api.trycloudflare | head -1)
  if [ -n "$url" ]; then
    echo "  地址: $url"
    for t in 1 2 3; do
      code=$(curl -s -m 25 --http1.1 -o /dev/null -w "%{http_code}" "$url/api/status")
      echo "  验证 $t: $code"
      [ "$code" = "200" ] && { echo "填进 App「电脑地址」: $url"; exit 0; }
      sleep 4
    done
  fi
  kill $pid 2>/dev/null
  echo "  第 $i 次拿域名失败，重试"
done
echo "隧道没起来，稍后再跑一次这个脚本" >&2
exit 1
