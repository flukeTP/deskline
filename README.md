# Deskline

Always-on-top quota glance for macOS — a **thin Deskline strip**, not a popup clone of ai-usage-counter.

Deskline keeps a slim floating strip on screen — **Claude · Codex · Cursor · Gemini · Antigravity** — plus a minimal menu bar icon and one glance %. Click the menu bar icon to slide down an expanded strip (orange accent, no arrow popup).

This repo is intentionally separate from [ai-usage-counter](https://github.com/lazymodthai/ai-usage-counter). That app is a rich popup monitor; Deskline optimizes for **persistent thin-strip glanceability**.

## MVP status

| Area | Status |
| --- | --- |
| Swift SPM menubar shell | Done |
| NSPanel HUD bar | Done |
| Settings (opacity, click-through, providers, refresh, accounts) | Done |
| Claude parser (`~/.claude/projects`) | Done |
| Codex parser (`~/.codex/sessions` + chatgpt.com API) | Done |
| Cursor parser (`cursor.com/api/usage-summary`) | Done |
| Gemini usage (DOM scrape) | Done |
| Antigravity local language server | Done |
| App icon + DMG packaging | Planned |

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

App bundle + DMG (v0.2.0):

```bash
./build.sh      # → build/Deskline.app
./release.sh    # → build/Deskline-0.2.0.dmg
```

Verify quota parsers without GUI:

```bash
.build/release/Deskline --verify
```

Look for the **Deskline** icon in the menu bar (`61%` glance). The floating strip appears centered near the top of the main screen by default. **Click** the menu bar icon for a slide-down expanded strip.

## Menu bar

- **Click** — toggle slide-down strip (Deskline mode) or reset/show detailed bar
- **Right-click** — Settings, Refresh, Hide/Show floating strip, Quit

## Privacy (target)

- Local parsers read files only on your Mac (`~/.claude/projects`, `~/.codex/sessions`).
- API-backed providers use authenticated requests from your Mac (same approach as ai-usage-counter).
- No third-party analytics.

## Repo

- GitHub: [flukeTP/deskline](https://github.com/flukeTP/deskline)
- Local path: `~/Documents/project/personal/deskline`

## License

MIT
