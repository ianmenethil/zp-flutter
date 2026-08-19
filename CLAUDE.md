# ZenPay SDK Monorepo Guidelines

This repository is a unified **Melos Monorepo** containing the complete ZenPay Dart and Flutter ecosystem. It is designed to provide secure, robust, and strongly-typed tools for merchants integrating ZenPay Hosted Checkout.

See [README.md](README.md) for the repo overview and quick start. `AGENTS.md` in this folder is a symlink to this file — edit `CLAUDE.md`, not `AGENTS.md`.

---

## 🔑 Design Rule: `merchantUniquePaymentId` Is Not Special

This has been reverted **four times** because an agent kept re-adding structure around it. Read this before touching `merchantUniquePaymentId` (MUPID) anywhere in this repo.

MUPID is an ordinary, opaque identifier the integrating application already owns and passes through. It is not a session key, not a correlation mechanism, and not something this SDK verifies, matches, or stores.

**Forbidden**, anywhere in `zenpay_flutter`:
- A required field on a public type (sealed base class, event, outcome, controller) that exists *specifically* for MUPID.
- A dedicated validation rule for MUPID (length, format, presence) beyond what applies to any other opaque string field.
- "Matches the id this checkout was launched with" / mismatch-rejection logic on a returned value.

**Why this looks tempting and is still wrong:** MUPID feels important because it's what merchants use to look up a payment. That is exactly why the SDK must *not* build machinery around it — doing so bakes one specific correlation strategy into the SDK's API surface, when correlation is the integrator's call to make. State is the integrating application's responsibility, not the SDK's.

**The actual stateless-correlation feature already exists:** `createZpCallbackUrlToken` / `verifyZpCallbackUrlToken` in `zenpay_dart` (see [zenpay_dart/lib/CLAUDE.md § 1](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_dart/lib/CLAUDE.md)) — a signed, verifiable token the backend embeds in the callback URL. That is how an integrator correlates a return without server-side state. It is not MUPID's job.

Before adding any code that treats MUPID differently from any other field on a request or response — stop and ask.

---

## 🏗️ Workspace Architecture & Agent Guides

Before modifying any package, you **must** read its specific agent guidelines. Each links back here and to its own `README.md`; `AGENTS.md` alongside every `CLAUDE.md` below is a symlink to it, not a separate file:

1. **[zenpay_dart/CLAUDE.md](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_dart/CLAUDE.md)** ([README](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_dart/README.md)): Pure Dart SDK guidelines. Covers all server-side logic, cryptography (SHA3-512, HMAC), token validation, and URL construction. Per-file source guide: [zenpay_dart/lib/CLAUDE.md](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_dart/lib/CLAUDE.md).
2. **[zenpay_flutter/CLAUDE.md](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/CLAUDE.md)** ([README](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/README.md)): Flutter Client SDK guidelines. Covers UI orchestration, deep-link return handling, URL launching, and client-side lifecycle. Per-file source guide: [zenpay_flutter/lib/CLAUDE.md](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/lib/CLAUDE.md).
3. **[example/CLAUDE.md](file:///G:/_zp-repos/zp-flutter-sdk/example/CLAUDE.md)** ([README](file:///G:/_zp-repos/zp-flutter-sdk/example/README.md)): Integration Example guidelines. Covers the mock merchant backend ([example/backend/CLAUDE.md](file:///G:/_zp-repos/zp-flutter-sdk/example/backend/CLAUDE.md)) and the test mobile app ([example/app/CLAUDE.md](file:///G:/_zp-repos/zp-flutter-sdk/example/app/CLAUDE.md)), demonstrating the full end-to-end payment flow.
4. **[scripts/README.md](file:///G:/_zp-repos/zp-flutter-sdk/scripts/README.md)**: Bootstrap, run, and platform-config scripts for the example app/backend.

---

## 🛠️ Monorepo Tooling (Melos)

We use [Melos](https://melos.invertase.dev) to manage dependencies and run verification commands across all packages simultaneously.

### Rules:

- **Never** run `flutter pub get` manually in subdirectories.
- Always use `melos bs` from the root to link local `path:` dependencies.

### Standard Pipeline:

Run these commands from the repository root to verify your changes across all packages:

```pwsh
melos bs
melos run format
melos run analyze
melos run lint
melos run test
```

---

## 🚨 Global Strictness & Code Quality

1. **Strict Type Safety**: All packages enforce `strict-casts`, `strict-inference`, and `strict-raw-types`. Avoid `dynamic` at all costs.
2. **Public API Documentation**: Any exported symbol in `lib/` for any package must have comprehensive dartdoc (`///`) explaining its purpose and failure modes.
3. **No Unused Code**: Clean up unused imports, variables, and private members immediately.
