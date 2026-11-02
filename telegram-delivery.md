---
layout: default
title: Telegram Notification
---

# 用 Telegram Bot 接收 Horizon 日报

Horizon 没有内置 Telegram 推送器，但它的通用 Webhook 可以直接调用 Telegram Bot API 的 `sendMessage`。不需要额外服务，也不需要写代码。

## 1. 创建 Bot

1. 在 Telegram 搜索 **@BotFather**，发送 `/newbot`。
2. 按提示设置显示名和用户名（用户名必须以 `bot` 结尾）。
3. BotFather 会返回一串 token，形如 `8123456789:AAH...`。这就是 `TELEGRAM_BOT_TOKEN`。

## 2. 拿到 chat_id

先让机器人能给你发消息：

- 私聊：打开你的 bot，点 **Start**（或发送任意消息）。
- 群组：把 bot 拉进群，并在群里发一条消息。

然后在浏览器打开：

```text
https://api.telegram.org/bot<你的TOKEN>/getUpdates
```

返回 JSON 里找 `"chat":{"id":...}`，这个数字就是 `chat_id`（群组是负数，例如 `-1001234567890`）。

> 如果 `getUpdates` 返回空数组，说明机器人还没收到过你的消息，先发一条再刷新。

## 3. 写入 `.env`

在 Horizon 根目录的 `.env` 中加入：

```dotenv
TELEGRAM_WEBHOOK_URL=https://api.telegram.org/bot<你的TOKEN>/sendMessage
TELEGRAM_CHAT_ID=<你的chat_id>
```

`TELEGRAM_WEBHOOK_URL` 是把 token 嵌进 URL 的完整地址，`TELEGRAM_CHAT_ID` 会由配置里的 `${TELEGRAM_CHAT_ID}` 自动替换。

## 4. 配置 `data/config.json`

仓库里的默认配置已经指向 Telegram：

```json
{
  "webhook": {
    "enabled": true,
    "url_env": "TELEGRAM_WEBHOOK_URL",
    "delivery": "summary_and_items",
    "overview_position": "first",
    "platform": "generic",
    "layout": "markdown",
    "languages": ["zh"],
    "request_body": {
      "chat_id": "${TELEGRAM_CHAT_ID}",
      "text": "#{message_title}\n\n#{summary?limit=3500&split=\n}",
      "disable_web_page_preview": true
    },
    "headers": ""
  }
}
```

关键点：

- `delivery: summary_and_items`：先发一条总览，再每条资讯发一条消息，避免单条超过 Telegram 的 4096 字符上限。
- `#{summary?limit=3500&split=\n}`：按行截断到 3500 字符，留出安全余量。
- `platform: "generic"`：让 Horizon 识别 Telegram 返回的 `{"ok": false, ...}` 并报告失败。不要改成 `telegram`，代码里没有这个平台分支。

## 5. 测试

先预览渲染结果，不会真的发送：

```powershell
uv run horizon-webhook --dry-run
```

确认 URL、`chat_id` 和正文无误后，发一条测试消息：

```powershell
uv run horizon-webhook --delivery summary
```

`--delivery summary` 只发一条截断后的摘要，适合测试；不加参数则按配置发送「总览 + 每条资讯」。

之后正常运行 `uv run horizon`，日报生成完就会自动推送。

## 6. 常用调整

| 想要的效果 | 改法 |
| --- | --- |
| 只发一条摘要 | `webhook.delivery` 改为 `"summary"` |
| 先发详情、最后发总览 | `overview_position` 改为 `"last"` |
| 更长/更短的单条消息 | 调整 `limit`，不要超过 4000 |
| 群组里不显示链接预览 | 保持 `disable_web_page_preview: true` |
| 换回飞书 | `platform`、`layout` 和 `request_body` 改回飞书卡片配置 |

## 7. 格式化说明

默认不设置 `parse_mode`，所以消息里的 `**`、`##`、`[标题](URL)` 会按原文显示。这样做的好处是**不会因为 Markdown 转义问题导致发送失败**（Telegram 的 Markdown 解析对未转义的 `_`、`*` 很敏感，URL 里的下划线也常触发 400）。

如果你能接受偶发的解析失败，可以在 `request_body` 里加：

```json
"parse_mode": "Markdown"
```

更稳妥的富文本方案是让 Horizon 推送到本地一个把 Markdown 转成 HTML 的小服务，再由它调用 Bot API。

## 8. 故障排查

| 现象 | 原因与处理 |
| --- | --- |
| 401 Unauthorized | token 错误，或 URL 里漏了 `bot` 前缀 |
| 400 chat not found | `chat_id` 错误，或你还没给 bot 发过消息 |
| 400 message is too long | 调小 `limit`，或改用 `summary_and_items` |
| 200 但没收到消息 | 检查 `chat_id` 是否指向了别的会话；`getUpdates` 里可能有多个 chat |
| 日志显示 skipped | `.env` 里 `TELEGRAM_WEBHOOK_URL` 为空，或没有加载 `.env` |

Horizon 的推送失败不会中断主流程，日报仍会写入 `data/summaries/` 和 `docs/_posts/`。
