# notebook-market-daily

用 GitHub Actions 每天自动汇总笔记本/PC 行情资讯，并推送到微信。零成本方案，不依赖任何付费 API。

## 数据源

| 来源 | 内容 | 方式 |
|---|---|---|
| IT之家 | 国内数码资讯 | RSS `https://www.ithome.com/rss/` |
| TechPowerUp | 海外硬件资讯 | RSS `https://www.techpowerup.com/rss/news` |
| Ars Technica | 备用海外源 | RSS `https://feeds.arstechnica.com/arstechnica/gadgets` |
| 京东 | 商品标价（可选） | `https://p.3.cn/prices/mgets?skuIds=J_<商品ID>`，非官方接口 |

抓取结果按关键词过滤后输出 `out/report.md`，内容是**标题 + 链接清单**，不含官方出货量统计（IDC/Canalys 明细为付费数据）。

## 运行

```
scripts/collect.sh    # 抓取并生成 out/report.md
scripts/notify.sh     # 推送报告到微信
```

手动触发：Actions 页面点 Run workflow，可填 `jd_sku_ids`（逗号分隔的京东 SKU ID）。
定时：每天 01:10 UTC（北京时间 09:10）。

## 微信推送

两种通道任选其一，密钥放在仓库 Secrets 里，**不要写进代码**：

| Secret | 对应服务 | 说明 |
|---|---|---|
| `SCT_KEY` | Server酱 | SendKey，个人微信通过服务号收消息 |
| `WEWORK_WEBHOOK` | 企业微信群机器人 | webhook 地址 |

两个都配置时优先 Server酱。都没配置时，报告只输出到 Actions 日志。

## 成本

- runner 固定 `ubuntu-latest`：Windows runner 单价是 Linux 的 5 倍，macOS 高 30 倍。
- 公开仓库的 Actions 用量标注为免费；即使按 Free 计划每月 2,000 分钟计，本项目每月约 30–90 分钟。
- 单个 job 上限 6 小时，本 workflow 设了 10 分钟超时。

## 已知限制

- 京东价格接口非官方，可能超时或变更；报告里是标价，不等于券后到手价。
- 报告是机器汇总的标题清单，未做事实核实，结论需人工查证原文。
- 公开仓库连续 60 天无活动，GitHub 会自动停用定时 workflow。
- schedule 触发在高负载时可能延迟，官方文档说明排队任务可能被直接丢弃。
