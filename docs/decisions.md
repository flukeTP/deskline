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

## Reference — ai-usage-counter parser map

| Provider | Source in ai-usage-counter | Data source |
| --- | --- | --- |
| Claude | `Sources/Providers/ClaudeProvider.swift`, `UsageParser.swift` | `~/.claude/projects` |
| Codex | `Sources/CodexLocalParser.swift`, `Providers/CodexProvider.swift` | `~/.codex/sessions` + chatgpt.com when signed in |
| Cursor | `Sources/Providers/CursorProvider.swift` | `cursor.com/api/usage-summary` when signed in |
| Shared | `CookieAPIFetcher.swift`, `WebAuthController.swift`, `WebViewFetcher.swift` | Auth + API fetch helpers |
