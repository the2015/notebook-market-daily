#!/usr/bin/env bash
# 抓取笔记本/PC 行情相关免费信息源，生成 report.md
# 不依赖任何付费 API，不写任何密钥到仓库
set -uo pipefail

OUT_DIR="${OUT_DIR:-out}"
REPORT="$OUT_DIR/report.md"
mkdir -p "$OUT_DIR"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

# 选一个可用的 Python 解释器（Windows 上 python3 可能是商店占位符）
if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys' >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "找不到可用的 Python 解释器"; exit 1
fi
echo "==> 使用 Python: $PY ($($PY --version 2>&1))"

# 关键词表：中文站点用中文词，英文站用英文词
CN_PATTERN='笔记本|轻薄本|游戏本|笔电|MacBook|MateBook|拯救者|ThinkPad|小新|Yoga|ROG|天选|无畏|处理器|CPU|显卡|GPU|内存|硬盘|笔记本显卡|RTX|Ryzen|酷睿|Core Ultra|OLED|折叠屏|平板'
EN_PATTERN='laptop|notebook|notebooks|ultrabook|gaming laptop|ThinkPad|MacBook|Ryzen|Core Ultra|Arrow Lake|Nova Lake|Intel|AMD|NVIDIA|GeForce|RTX|DRAM|NAND|SSD|memory chip|price cut|discount'

# fetch <name> <url> -> 落地文件，失败返回非 0
fetch() {
  local name="$1" url="$2"
  if curl -sSL -m 30 --retry 2 --retry-delay 3 \
      -A "$UA" -o "$TMP/$name" "$url" 2>/dev/null && [ -s "$TMP/$name" ]; then
    echo "OK   $name"
    return 0
  fi
  echo "FAIL $name"
  return 1
}

# 提取 RSS item 的 title + link + pubDate
parse_rss() {
  local file="$1" pattern="$2" limit="${3:-12}"
  "$PY" - "$file" "$pattern" "$limit" <<'PY'
import re, sys, html
path, pattern, limit = sys.argv[1], sys.argv[2], int(sys.argv[3])
try:
    raw = open(path, encoding='utf-8', errors='ignore').read()
except Exception:
    sys.exit(0)

items = re.findall(r'<item\b.*?</item>', raw, re.S)
rx = re.compile(pattern, re.I)
out = []
for it in items:
    t = re.search(r'<title>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>', it, re.S)
    if not t:
        continue
    title = html.unescape(re.sub(r'<[^>]+>', '', t.group(1))).strip()
    if not title or not rx.search(title):
        continue
    l = re.search(r'<link>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</link>', it, re.S)
    link = html.unescape(l.group(1)).strip() if l else ''
    d = re.search(r'<pubDate>(.*?)</pubDate>', it, re.S)
    date = html.unescape(d.group(1).strip()) if d else ''
    if link:
        title = f"{title} —— {link}"
    if date:
        title = f"{title}（{date}）"
    out.append(title)
    if len(out) >= limit:
        break
print('\n'.join(out))
PY
}

# 京东商品标价（无 key，非官方接口，可能超时/变更）；失败则跳过
jd_prices() {
  local ids="$1"
  [ -z "$ids" ] && return 0
  local url="https://p.3.cn/prices/mgets?skuIds=$(echo "$ids" | sed 's/[^0-9,]//g' | sed 's/,,*/,/g')"
  curl -sSL -m 20 -A "$UA" "$url" 2>/dev/null
}

echo "==> 抓取数据源"

CN_SRC=""
EN_SRC=""

if fetch ithome.xml "https://www.ithome.com/rss/"; then
  CN_SRC="$TMP/ithome.xml"
fi
if fetch tpu.xml "https://www.techpowerup.com/rss/news"; then
  EN_SRC="$TMP/tpu.xml"
fi
# 备用源：任一成功即可
if [ -z "$CN_SRC" ]; then
  fetch ars.xml "https://feeds.arstechnica.com/arstechnica/gadgets" && CN_SRC="$TMP/ars.xml"
fi

echo "==> 生成报告"

{
  echo "# 笔记本行情日报"
  echo
  echo "生成时间：$(date -u '+%Y-%m-%d %H:%M UTC')"
  echo
} > "$REPORT"

echo "## 一、国内资讯（IT之家）" >> "$REPORT"
if [ -n "$CN_SRC" ]; then
  cn=$(parse_rss "$CN_SRC" "$CN_PATTERN" 12)
  if [ -n "$cn" ]; then
    echo "$cn" | sed 's/^/- /' >> "$REPORT"
  else
    echo "- 本轮未匹配到笔记本相关条目（RSS 正常，但关键词未命中）" >> "$REPORT"
  fi
else
  echo "- 数据源不可达，本次未获取" >> "$REPORT"
fi
echo >> "$REPORT"

echo "## 二、海外资讯（TechPowerUp / Ars Technica）" >> "$REPORT"
if [ -n "$EN_SRC" ]; then
  en=$(parse_rss "$EN_SRC" "$EN_PATTERN" 12)
  if [ -n "$en" ]; then
    echo "$en" | sed 's/^/- /' >> "$REPORT"
  else
    echo "- 本轮未匹配到笔记本相关条目" >> "$REPORT"
  fi
else
  echo "- 数据源不可达，本次未获取" >> "$REPORT"
fi
echo >> "$REPORT"

echo "## 三、京东标价（可选）" >> "$REPORT"
JD_SKU_IDS="${JD_SKU_IDS:-}"
if [ -n "$JD_SKU_IDS" ]; then
  raw=$(jd_prices "$JD_SKU_IDS")
  if [ -n "$raw" ]; then
    echo '```json' >> "$REPORT"
    echo "$raw" >> "$REPORT"
    echo '```' >> "$REPORT"
  else
    echo "- 京东价格接口不可达（可能超时或接口已变更）" >> "$REPORT"
  fi
else
  echo "- 未配置 JD_SKU_IDS，跳过。可在 workflow 中设置该变量启用。" >> "$REPORT"
fi
echo >> "$REPORT"

echo "## 四、口径说明" >> "$REPORT"
cat <<'EOF' >> "$REPORT"
- 以上为公开 RSS 资讯标题与链接，不含官方出货量统计（IDC/Canalys 明细为付费）。
- 京东一节为商品标价（标价），不等于券后到手价；接口非官方，可能失效。
- 报告为机器自动汇总的标题清单，未做事实核实，价格与销量结论需人工查证原文。
EOF

echo "==> 完成：$REPORT"
wc -l "$REPORT"
