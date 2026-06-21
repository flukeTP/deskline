# Architecture decisions

Lightweight decision log for Deskline. Not a full ADR process — solo personal project.

## 2026-06-19 — Separate repo from ai-usage-counter

**Decision:** Deskline lives in its own repo (`flukeTP/deskline`) at `~/Documents/project/personal/deskline`.

**Context:** ai-usage-counter is a menu bar popup with multi-provider cards, Antigravity/Gemini support, and a different UX goal (inspect on click). Deskline targets a **persistent HUD glance** — one thin bar, always visible.

**Consequences:**

- No coupling to ai-usage-counter release cadence or branding.
- Parser code is copied/adapted when needed; drift is acceptable short-term.
- Two apps can coexist on one Mac.

---

## 2026-06-19 — HUD = NSPanel, not WidgetKit (MVP)

**Decision:** MVP uses a borderless `NSPanel` at `.floating` level, not WidgetKit.

**Context:** WidgetKit needs an extension target, timeline providers, and does not give the same always-on-top desktop overlay behavior without extra constraints.

**Consequences:**

- Faster MVP; matches "strip on screen" mental model.
- WidgetKit deferred to v2+ (see ROADMAP).
- Click-through and opacity are panel properties, not widget configuration.

---

## 2026-06-19 — Solo delivery, no full spec-TDD gate

**Decision:** Skip Knowledge-Agents plan-first / spec-TDD workflow for this personal repo.

**Context:** Single developer, small surface area, experimental UX. Governance overhead does not pay off yet.

**Consequences:**

- README + ROADMAP + this file are enough structure for now.
- Revisit if the project grows (packaging, signing, multi-module).

---

## 2026-06-19 — Parsers copied/adapted, not shared package

**Decision:** Do not extract a shared Swift package between Deskline and ai-usage-counter yet.

**Context:** Deskline needs a narrower provider set (Claude, Codex, Cursor) and a different data model (`QuotaSnapshot` vs `ProviderUsage`). Premature shared package adds versioning friction.

**Consequences:**

- Copy/adapt from `~/Documents/project/public/ai-usage-counter` per provider.
- Note upstream file paths in ROADMAP when porting.
- Re-evaluate shared package only if both repos stabilize and drift hurts maintenance.

---

## 2026-06-19 — MVP providers: Claude, Codex, Cursor only

**Decision:** Gemini and Antigravity are out of MVP scope.

**Context:** User's primary glance targets; Gemini/Antigravity add WebView/auth complexity with lower priority.

**Consequences:** Listed under "Later providers" in ROADMAP.

---

## 2026-06-21 — v1 threshold alerts: global, strip-first, fire-once

**Decision:** Alerts use a single global warn/critical pair (default 80/95), surfaced on the strip first (warn outline, critical pulse), with an optional macOS notification and a menu bar badge dot. Notifications fire once per upward crossing and re-arm only after usage drops below warn.

**Context:** Solo use — per-provider thresholds add settings UI without real payoff. The strip is always visible, so it is the primary alert channel; notifications are for when the strip is off-screen/ignored. A provider parked at 88% must not re-notify every refresh.

**Consequences:**

- `AlertEngine` tracks last level per provider and only acts on `level.rank > previous.rank` (escalation-gated). Re-evaluated on every quota change and on settings change.
- macOS notifications need a bundle id + code signing → work from `build/Deskline.app`, not `swift run`. `requestAuthorization` is bundle-guarded so dev runs degrade gracefully.
- Per-provider thresholds deferred (see ROADMAP).
- "Preview alert styles" toggle added for a one-tap visual check without crossing real thresholds.

---

## 2026-06-21 — Nasdaq module reads state.json (local-first), not the API

**Decision:** The NASDAQ strip glance reads `~/Documents/project/personal/nasdaq-signal/alerts/state.json` directly (a `{ ticker: "up"|"down"|"flat" }` map), rather than calling nasdaq-signal's Next.js API routes.

**Context:** nasdaq-signal runs locally (`npm run dev`) and is not deployed. Hitting `localhost:3000/api/signals` would require the dev server to be running — fragile for an always-on menu bar app. `state.json` is written by the background scorer (GitHub Actions commits it), so it is a free, dependency-free local source consistent with how Deskline already reads `~/.claude` / `~/.codex`.

**Consequences:**

- Glance reflects the last *synced* signals — it refreshes when `state.json` changes on disk (e.g. after `git pull`), not in real time. Acceptable for a glance.
- Reloaded on the normal refresh timer (state.json changes rarely, so no FSEvents watcher — the existing FileWatcher only matches `.jsonl` anyway).
- Path follows the dev-path convention from `MenuBarIcon`. A live localhost-API source and per-ticker expanded view are deferred (see ROADMAP).
- Module is opt-in (`showNasdaqModule`, default off) so non-stock users are unaffected.

---

## 2026-06-21 — Strip = ambient mood; per-ticker/flips = widget

**Decision:** The Watchlist strip cell stays a single terse glance (directional arrow + up/down counts, colored by net tilt). Per-ticker breakdown and flip highlighting are NOT on the strip — they are reserved for the planned WidgetKit widget.

**Context:** Per-ticker on the strip looks cluttered next to the AI quota cells. More importantly, `state.json` only changes on sync/pull, so a strip "flip" badge would appear for a single refresh cycle and almost never be seen — flip signals need a persistent, acknowledgeable surface. The widget is that surface.

**Consequences:**

- Strip answers one question: "which way is my watchlist leaning right now." Renamed "NASDAQ" → "Watchlist" (it is the user's list, not the index).
- The widget (v2 WidgetKit) owns per-ticker rows + flip detection (compare against a persisted previous state).
- Internal type names (`NasdaqGlance`, `showNasdaqModule`) kept to avoid churn; user-facing strings say "Watchlist".

---

## Reference — ai-usage-counter parser map

| Provider | Source in ai-usage-counter | Data source |
| --- | --- | --- |
| Claude | `Sources/Providers/ClaudeProvider.swift`, `UsageParser.swift` | `~/.claude/projects` |
| Codex | `Sources/CodexLocalParser.swift`, `Providers/CodexProvider.swift` | `~/.codex/sessions` + chatgpt.com when signed in |
| Cursor | `Sources/Providers/CursorProvider.swift` | `cursor.com/api/usage-summary` when signed in |
| Shared | `CookieAPIFetcher.swift`, `WebAuthController.swift`, `WebViewFetcher.swift` | Auth + API fetch helpers |
