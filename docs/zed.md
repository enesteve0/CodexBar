---
summary: "Zed provider data sources: editor Keychain session, Zed cloud API, and optional dashboard billing cookies for live token spend."
read_when:
  - Debugging Zed usage fetch
  - Updating Zed Keychain or cloud API handling
  - Adjusting Zed provider UI/menu behavior
  - Enabling experimental dashboard token billing
---

# Zed provider

CodexBar monitors Zed plan status, billing cycle dates, edit-prediction quota, and billing warnings via Zed’s internal cloud API. **Live Zed-hosted token-dollar spend** is available only when dashboard session cookies are imported (Phase 2, experimental).

## Data source

**Local probe (Keychain + cloud API)** — reads the same credentials Zed stores after GitHub sign-in, then calls:

```text
GET https://cloud.zed.dev/client/users/me
Authorization: {user_id} {access_token}
```

### Keychain credentials

| Item | Value |
| --- | --- |
| Service URL | `https://zed.dev` by default, or custom `credentials_url` from `~/Library/Application Support/Zed/settings.json` |
| Keychain class | **Internet password** (`kSecClassInternetPassword`, server = service URL). Generic-password fallback is supported for older layouts. |
| Account | Zed user ID (string) |
| Secret | Access token (UTF-8 bytes) |

CodexBar uses `KeychainNoUIQuery` for non-interactive reads. If Zed has never been signed in, or CodexBar lacks Keychain access, the provider reports **Not signed in to Zed**.

### Settings override

Zed’s `credentials_url` setting (falls back to `server_url`) selects which Keychain entry to read. This supports side-by-side Zed installs with different user data directories.

## Phase 2 — Dashboard token billing (experimental)

### Spike findings (2026-06)

The dashboard SPA (`dashboard.zed.dev`) calls an **undocumented JSON endpoint** on the same cloud host:

```text
GET https://cloud.zed.dev/frontend/billing/usage
Cookie: {dashboard session cookies}
Accept: application/json
```

**Contract (from dashboard bundle validation schemas, redacted fixtures in tests):**

| Field | Meaning |
| --- | --- |
| `plan` | Plan slug (`zed_pro`, `zed_student`, …) |
| `current_usage.token_spend.spend_in_cents` | Current-period token spend (cents) |
| `current_usage.token_spend.limit_in_cents` | Monthly spend threshold when above included credits |
| `current_usage.token_spend.updated_at` | Optional cache timestamp |

Orb invoice history remains embedded in the dashboard UI, but **token spend meters use this JSON route**, not the Orb iframe.

**Auth:** Dashboard browser session cookies on `cloud.zed.dev` / `zed.dev` / `dashboard.zed.dev`. Editor Keychain tokens do **not** authenticate this route.

**Fragility:** Undocumented frontend API; schema may change without notice. CodexBar labels this path experimental and falls back to Phase 1 static labels on any failure.

### Cookie settings

| Setting | Default | Behavior |
| --- | --- | --- |
| Dashboard cookie source | **Off** | No browser Keychain prompts; token spend stays static |
| Auto | — | Chrome-only import (`ProviderBrowserCookieDefaults.zedCookieImportOrder`) |
| Manual | — | Paste `Cookie` header copied from DevTools on a signed-in billing page |

When enrichment succeeds, CodexBar merges live token spend into the menu card (`usageKnown: true`, source label `local+zed-dashboard`). Failures are silent — primary Keychain/cloud refresh still succeeds.

## Snapshot mapping

| Zed field | CodexBar display |
| --- | --- |
| `plan.plan_v3` | Plan label (Free / Pro / Trial / Student / Business) |
| `plan.usage.edit_predictions` | Primary bar: used/limit or “Unlimited” on Pro+ |
| `plan.subscription_period.ended_at` | Billing cycle reset / secondary window |
| Dashboard `token_spend` (optional) | Live token credits bar when cookie import enabled |
| Static included credits (fallback) | Pro $5, Student $10, Trial $20 from docs |
| `plan.has_overdue_invoices` | Warning note + billing window marker |

## Limitations

### Dashboard vs editor auth

- **Editor sign-in** → Keychain → `/client/users/me` (plan + edit predictions).
- **Dashboard sign-in** → browser cookies → `/frontend/billing/usage` (token spend).
- Signing into one does not enable the other.

### Not tracked as “Zed”

Per [LLM Providers](https://zed.dev/docs/ai/llm-providers.html) and [External Agents](https://zed.dev/docs/ai/external-agents.html):

- BYOK models → track via OpenAI, Claude, Gemini, etc.
- External agents (Claude Agent, Codex ACP) → bill through those providers

### Undocumented APIs

Both `/client/users/me` and `/frontend/billing/usage` are internal Zed surfaces, not published integrations.

## Troubleshooting

### “Not signed in to Zed”
- Sign in from the **Zed editor app** (Command Palette → `client: sign in`), not only dashboard.zed.dev in a browser.
- Confirm a Keychain internet-password entry exists for server `https://zed.dev` (or your custom `credentials_url`).

### “Could not read Zed credentials from the Keychain”
- macOS may block Keychain access until you allow CodexBar (same class of issue as other IDE probes).
- Re-sign in to Zed after changing `credentials_url`.

### Plan matches Zed but token spend is still static
- Expected when **Dashboard cookie source** is **Off** (default).
- Sign into [dashboard.zed.dev](https://dashboard.zed.dev) in Chrome, enable cookie import (Auto or Manual), and refresh.
- Confirm DevTools shows `200` for `cloud.zed.dev/frontend/billing/usage` on the billing page.

## Key files

- `Sources/CodexBarCore/Providers/Zed/ZedStatusProbe.swift` — Keychain read, cloud API, snapshot mapping
- `Sources/CodexBarCore/Providers/Zed/ZedDashboardBillingFetcher.swift` — dashboard billing JSON fetch/parse
- `Sources/CodexBarCore/Providers/Zed/ZedCookieImporter.swift` — Chrome-first dashboard cookie import
- `Sources/CodexBarCore/Providers/Zed/ZedProviderDescriptor.swift` — enriched local fetch strategy
- `Sources/CodexBar/Providers/Zed/ZedSettingsStore.swift` — cookie settings (default Off)
- `Sources/CodexBar/Providers/Zed/ZedProviderImplementation.swift` — settings UI
- `Tests/CodexBarTests/ZedStatusProbeTests.swift` — cloud API fixture tests
- `Tests/CodexBarTests/ZedDashboardBillingTests.swift` — billing parse/merge tests
