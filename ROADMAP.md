# Deskline ROADMAP

## MVP (in progress)

- [x] Swift SPM + menu bar accessory app
- [x] NSPanel HUD — single bar, always on top
- [x] Settings: opacity, click-through, provider toggles, refresh interval
- [x] Stub quota coordinator (placeholder percentages)
- [ ] Port **Claude** parser from ai-usage-counter (`~/.claude/projects`)
- [ ] Port **Codex** local parser (`~/.codex/sessions`)
- [ ] Port **Codex** web/API path when signed in to chatgpt.com
- [ ] Port **Cursor** API path (`cursor.com/api/usage-summary`) when signed in
- [ ] File watchers for local providers (refresh on change)
- [ ] WebKit auth flow for Codex + Cursor (adapt from ai-usage-counter)
- [ ] App icon + DMG packaging

### MVP HUD format

```text
Claude 42% · Codex 68% · Cursor 55%
```

Show only enabled providers. Color shifts toward orange/red above ~70% / ~90% used.

---

## v1 — Threshold alerts

- [ ] Per-provider warning threshold (e.g. 80%)
- [ ] macOS notification when crossed
- [ ] Optional menu bar badge when any provider is hot
- [ ] Snooze / cooldown so alerts do not spam

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

- [ ] **Gemini** — adapt beta flow from ai-usage-counter
- [ ] **Antigravity** — local language-server quotas

---

## Non-goals (for now)

- Cross-repo Swift package shared with ai-usage-counter
- Full spec-TDD / Bot's Zoo governance workflow (solo personal project)
- Knowledge-Agents project overlay
