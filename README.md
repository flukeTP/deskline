# Deskline

Always-on-top HUD bar for glancing at AI provider quotas on macOS.

Deskline is a personal menu bar app that keeps a slim floating strip on screen — **Claude · Codex · Cursor** — so you can see usage without opening each provider's settings page.

This repo is intentionally separate from [ai-usage-counter](https://github.com/lazymodthai/ai-usage-counter). That app is a rich popup monitor; Deskline optimizes for **persistent glanceability**.

## MVP status

| Area | Status |
| --- | --- |
| Swift SPM menubar shell | Done |
| NSPanel HUD bar | Done (stub data) |
| Settings (opacity, click-through, providers, refresh) | Done |
| Claude parser (`~/.claude/projects`) | Planned |
| Codex parser (`~/.codex/sessions` + chatgpt.com API) | Planned |
| Cursor parser (`cursor.com/api/usage-summary`) | Planned |

Parser logic will be **copied/adapted** from `~/Documents/project/public/ai-usage-counter` — not shared as a cross-repo package yet.

## Requirements

- macOS 14 Sonoma or later
- Swift 5.9+

## Run from source

```bash
cd ~/Documents/project/personal/deskline
swift build
swift run
```

Release build:

```bash
swift build -c release
.build/release/Deskline
```

Look for the **Deskline** icon in the menu bar. The HUD appears centered near the top of the main screen.

## Menu bar

- **Settings…** — opacity, click-through, enabled providers, refresh interval
- **Hide / Show HUD**
- **Refresh Now**
- **Quit**

## Privacy (target)

- Local parsers read files only on your Mac (`~/.claude/projects`, `~/.codex/sessions`).
- API-backed providers use authenticated requests from your Mac (same approach as ai-usage-counter).
- No third-party analytics.

## Repo

- GitHub: [flukeTP/deskline](https://github.com/flukeTP/deskline)
- Local path: `~/Documents/project/personal/deskline`

## License

MIT
