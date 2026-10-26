#!/usr/bin/env bash
# 把 report.md 推送到微信。
# 支持三种通道，按已配置的密钥自动选择；都没配就只输出到日志。
set -uo pipefail

REPORT="${REPORT:-out/report.md}"
[ -f "$REPORT" ] || { echo "找不到 $REPORT"; exit 1; }

body=$(cat "$REPORT")

if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys' >/dev/null 2>&1; then
  PY=python3
else
  PY=python
fi

# Server酱：个人微信通过服务号收消息
if [ -n "${SCT_KEY:-}" ]; then
  echo "==> 发送 Server酱"
  payload=$("$PY" - "$body" <<'PY'
import json, sys
print(json.dumps({"title": "笔记本行情日报", "desp": sys.argv[1]}, ensure_ascii=False))
PY
)
  resp=$(curl -sS -m 30 -X POST "https://sctapi.ftqq.com/${SCT_KEY}.send" \
    -H "Content-Type: application/json" -d "$payload" 2>&1)
  echo "Server酱响应: $resp"
  if echo "$resp" | grep -q '"code":0'; then
    echo "==> Server酱发送成功"
    exit 0
  fi
fi

# 企业微信群机器人
if [ -n "${WEWORK_WEBHOOK:-}" ]; then
  echo "==> 发送企业微信群机器人"
  payload=$("$PY" - "$body" <<'PY'
import json, sys
print(json.dumps({"msgtype": "markdown", "markdown": {"content": sys.argv[1]}}, ensure_ascii=False))
PY
)
  resp=$(curl -sS -m 30 -X POST "$WEWORK_WEBHOOK" \
    -H "Content-Type: application/json" -d "$payload" 2>&1)
  echo "企业微信响应: $resp"
  if echo "$resp" | grep -q '"errcode":0'; then
    echo "==> 企业微信发送成功"
    exit 0
  fi
fi

# 兜底：打印到 workflow 日志
echo "==> 未配置推送通道（SCT_KEY / WEWORK_WEBHOOK），仅输出到日志"
echo "$body"
