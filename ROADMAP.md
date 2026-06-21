# Deskline ROADMAP

## MVP (in progress)

- [x] Swift SPM + menu bar accessory app
- [x] NSPanel HUD — single bar, always on top
- [x] Settings: opacity, click-through, provider toggles, refresh interval
- [x] Stub quota coordinator (placeholder percentages)
- [x] Port **Claude** parser from ai-usage-counter (`~/.claude/projects`)
- [x] Port **Cursor** API path (`cursor.com/api/usage-summary`) when signed in
- [x] Port **Codex** local parser (`~/.codex/sessions`)
- [x] Port **Codex** web/API path when signed in to chatgpt.com
- [x] Port **Gemini** DOM scrape (beta)
- [x] Port **Antigravity** local language-server quotas (optional)
- [x] File watchers for local providers (refresh on change)
- [x] WebKit auth flow for Codex + Cursor + Gemini + Antigravity
- [x] App icon + DMG packaging (`./build.sh`, `./release.sh`)

### MVP HUD format

```text
Claude 42% · Codex 68% · Cursor 55%
```

Show only enabled providers. Color shifts toward orange/red above ~70% / ~90% used.

HUD shows the higher of session vs weekly usage (or max quota lane for Antigravity/Gemini lanes).

---

## v1 — Threshold alerts ✅

- [x] Global warn (80%) + critical (95%) thresholds, adjustable in Settings
- [x] Strip highlight: warn = colored outline, critical = pulsing outline
- [x] macOS notification when crossed (built `.app` only — needs a bundle id)
- [x] Menu bar badge dot when any provider is hot (orange warn / red critical)
- [x] Fire-once + re-arm so alerts do not spam
- [x] "Preview alert styles" toggle for a one-tap visual check
- [ ] Per-provider thresholds (deferred — global is enough for solo use)

---

## v2+ — WidgetKit

- [ ] Desktop widget (small/medium) mirroring HUD data
- [ ] **Watchlist widget: per-ticker signals + flip highlights** (the detailed,
      acknowledgeable view — deliberately kept off the terse strip)
- [ ] Lock Screen / Notification Center widget (if useful)
- [ ] Shared data container between app and widget extension

---

## v2+ — Watchlist (stock) module ✅ (v1 shipped)

- [x] Second strip module: nasdaq-signal glance (separate from AI quota)
- [x] Local-first source: reads `nasdaq-signal/alerts/state.json` (no server)
- [x] Terse strip cell: directional arrow + ▲ up / ▼ down counts, colored by net tilt
- [x] Settings toggle "Show Watchlist glance" + empty-state hint
- [x] Unit tests for parse/tilt/summary
- Design: strip = ambient mood glance only; per-ticker + flip detection belong
  in the widget (state.json changes too rarely for a flip badge to be visible
  on the strip). See decisions.md (2026-06-21).
- [ ] Later: live source via localhost API when the dev server is up

---

## Later providers

- [x] **Gemini** — DOM scrape (ported from ai-usage-counter)
- [x] **Antigravity** — local language-server quotas (optional; disable in Settings)

---

## Non-goals (for now)

- Cross-repo Swift package shared with ai-usage-counter
- Full spec-TDD / Bot's Zoo governance workflow (solo personal project)
- Knowledge-Agents project overlay
