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
| App icon + DMG packaging | Done |
| v1 threshold alerts (strip highlight + pulse) | Done |
| macOS notification on crossing (fire-once) | Done |
| Menu bar badge dot when a provider is hot | Done |

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

App bundle + DMG (v0.2.1):

```bash
./build.sh      # → build/Deskline.app
./release.sh    # → build/Deskline-0.2.1.dmg
```

Run the unit tests (alert threshold + escalation logic):

```bash
swift test
```

Verify quota parsers + computed alert levels without GUI:

```bash
.build/release/Deskline --verify
```

Look for the **Deskline** icon in the menu bar (`61%` glance). The floating strip appears centered near the top of the main screen by default. **Click** the menu bar icon for a slide-down expanded strip.

## Menu bar

- **Click** — toggle slide-down strip (Deskline mode) or reset/show detailed bar
- **Right-click** — Settings, Refresh, Hide/Show floating strip, Quit

## Alerts

When a provider's usage crosses a threshold, Deskline highlights it so you don't have to keep checking:

- **Warn** (default 80%) — colored outline around the provider on the strip + an orange dot on the menu bar.
- **Critical** (default 95%) — pulsing outline on the strip + a red dot on the menu bar.
- **macOS notification** — fires once each time a provider crosses up, then re-arms after it drops below warn (no spam).

Adjust thresholds and toggles in **Settings → Alerts**. Use **Preview alert styles** there to see the strip styling instantly without waiting for real usage.

> Notifications require running the built `Deskline.app` (they need a bundle id + code signing). `swift run` shows the strip/badge but cannot post notifications.

## Watchlist module

Enable **Settings → Modules → Show Watchlist glance** to add a stock-signal cell to the strip, sourced from [nasdaq-signal](https://github.com/flukeTP/nasdaq-signal)'s local `alerts/state.json`:

- A single **ambient glance** of your watchlist's net tilt: a directional arrow (↗ bullish / ↘ bearish / – neutral) plus **▲ up / ▼ down** counts, colored to match.
- Reads the file directly — no server needed. Refreshes when `state.json` syncs (e.g. after the background scorer commits and you pull).

The strip stays terse on purpose (mood at a glance). **Per-ticker detail and flip alerts are reserved for the planned desktop widget**, not the strip. Opt-in and off by default.

## Privacy (target)

- Local parsers read files only on your Mac (`~/.claude/projects`, `~/.codex/sessions`).
- API-backed providers use authenticated requests from your Mac (same approach as ai-usage-counter).
- No third-party analytics.

## Repo

- GitHub: [flukeTP/deskline](https://github.com/flukeTP/deskline)
- Local path: `~/Documents/project/personal/deskline`

## License

MIT
