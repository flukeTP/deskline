# Parser porting notes

Parsers adapted from:

```text
~/Documents/project/public/ai-usage-counter
```

## Deskline file map

| Provider | Deskline | Upstream |
| --- | --- | --- |
| Claude local | `Sources/Parsers/ClaudeUsageParser.swift` | `UsageParser.swift` |
| Claude API | `Sources/Providers/ClaudeQuotaEngine.swift` | `ClaudeProvider.swift` |
| Cursor | `Sources/Providers/CursorQuotaEngine.swift` | `CursorProvider.swift` |
| Codex local | `Sources/Parsers/CodexLocalParser.swift` | same |
| Codex API | `Sources/Providers/CodexQuotaEngine.swift` | `CodexProvider.swift` |
| Gemini | `Sources/Providers/GeminiQuotaEngine.swift` | `GeminiProvider.swift` |
| Antigravity | `Sources/Providers/AntigravityQuotaEngine.swift` | `AntigravityProvider.swift` |
| Shared | `Sources/Support/*` | `CookieAPIFetcher`, `WebViewFetcher`, `WebAuthController`, `FileWatcher` |

Wrappers: `Sources/Providers/DesklineQuotaProviders.swift` → `QuotaSnapshot` for HUD.
