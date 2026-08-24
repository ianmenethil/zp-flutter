# example — Combined Reference Integration

Single example demonstrating the full ZenPay Hosted Checkout flow using both published SDKs together: a backend session/callback service and the Flutter client that presents checkout.

---

## Related Guides

- **[Monorepo Root](../CLAUDE.md)** — Melos workspace overview.
- **[Pure Dart SDK](../zenpay_dart/CLAUDE.md)** — Server-side cryptography, models, and token validation.
- **[Flutter Client SDK](../zenpay_flutter/CLAUDE.md)** — UI and client-side orchestration.
- **[example/backend/CLAUDE.md](backend/CLAUDE.md)** — This example's Shelf backend, in detail.
- **[example/app/CLAUDE.md](app/CLAUDE.md)** — This example's Flutter app, in detail.
- **[README.md](README.md)** — How to run both halves together.

---

## 1. Architecture: The Two-App Pattern

Because ZenPay involves secure payments, it requires a backend. Thus, the `example/` folder contains two separate applications:

| Folder                 | Depends on (Local Path) | Role                                                                                                                  |
| ---------------------- | ----------------------- | --------------------------------------------------------------------------------------------------------------------- |
| **`example/backend/`** | `zenpay_dart`           | A Shelf server. Holds API keys, creates secure sessions, builds launch URLs, and verifies ZenPay webhooks.            |
| **`example/app/`**     | `zenpay_flutter`        | A Flutter mobile app. Fetches a session from the backend, presents the checkout UI, and handles the return deep-link. |

---

## 2. Dependency source — Local `path:` via Melos

- `backend/` depends on **`zenpay_dart`** using a local `path:` dependency (`../../zenpay_dart`).
- `app/` depends on **`zenpay_flutter`** using a local `path:` dependency (`../../zenpay_flutter`).

**Why:** This repository is a unified Melos monorepo. During development and testing, the examples must link directly to the local packages to ensure all changes are instantly verifiable across the entire SDK. When running `melos bootstrap` at the root, these paths are automatically managed.

_(Note: When users clone this example from GitHub in the future, they will replace the `path:` overrides with standard `pub.dev` version constraints)._

---

## 3. Look and Feel Guidelines

- **UI/Visual Design**: Specified by the project owner, not invented here. Do not build or guess at UI before that spec is given.
- **Simplicity**: The example app should be minimal and focused entirely on demonstrating the integration of the SDKs, avoiding complex third-party state management libraries unless requested.

---

## 4. Verification

This directory holds no source of its own — see [example/backend § Verification Commands](backend/CLAUDE.md#3-verification-commands) and [example/app § Verification Commands](app/CLAUDE.md#3-verification-commands) for the two halves. From the **repository root**, both are covered by:

```pwsh
melos run format
melos run analyze
melos run test
```
