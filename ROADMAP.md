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
- [ ] Lock Screen / Notification Center widget (if useful)
- [ ] Shared data container between app and widget extension

---

## v2+ — Nasdaq module

- [ ] Second HUD module: nasdaq-signal glance (separate from AI quota)
- [ ] Code reference: `~/Documents/project/personal/nasdaq-signal`
- [ ] Toggle modules in settings (AI only vs stocks only vs both)

---

## Later providers

- [x] **Gemini** — DOM scrape (ported from ai-usage-counter)
- [x] **Antigravity** — local language-server quotas (optional; disable in Settings)

---

## Non-goals (for now)

- Cross-repo Swift package shared with ai-usage-counter
- Full spec-TDD / Bot's Zoo governance workflow (solo personal project)
- Knowledge-Agents project overlay
