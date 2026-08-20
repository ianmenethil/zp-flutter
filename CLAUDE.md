# ZenPay SDK Monorepo Guidelines

This repository is a unified **Melos Monorepo** containing the complete ZenPay Dart and Flutter ecosystem. It is designed to provide secure, robust, and strongly-typed tools for merchants integrating ZenPay Hosted Checkout.

See [README.md](README.md) for the repo overview and quick start. `AGENTS.md` in this folder is a symlink to this file — edit `CLAUDE.md`, not `AGENTS.md`.

---

## 📐 Source of Truth: The TypeScript SDK

This monorepo is a port of the TypeScript ZenPay HCP SDK (`@ianmenethil/zp-hcp`), maintained at `F:\_ZP-Main\apps\HPP-TS`. When behavior, an edge case, or a design decision is unclear or undocumented here, look up how the TypeScript source handles it and follow that established behavior — don't invent new logic. Deviating from the TypeScript SDK is a decision, not a default: flag it and ask before diverging.

---

## 🏗️ Workspace Architecture & Agent Guides

Before modifying any package, you **must** read its specific agent guidelines. Each links back here and to its own `README.md`; `AGENTS.md` alongside every `CLAUDE.md` below is a symlink to it, not a separate file:

1. **[zenpay_dart/CLAUDE.md](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_dart/CLAUDE.md)** ([README](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_dart/README.md)): Pure Dart SDK guidelines. Covers all server-side logic, cryptography (SHA3-512, HMAC), token validation, and URL construction. Per-file source guide: [zenpay_dart/lib/CLAUDE.md](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_dart/lib/CLAUDE.md).
2. **[zenpay_flutter/CLAUDE.md](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/CLAUDE.md)** ([README](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/README.md)): Flutter Client SDK guidelines. Covers UI orchestration, deep-link return handling, URL launching, and client-side lifecycle. Per-file source guide is inline in the same file — there is no separate `lib/CLAUDE.md`.
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
