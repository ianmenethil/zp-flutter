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

## 2. Dependency source — the Dart pub workspace

- `backend/` depends on **`zenpay_dart`** via an ordinary version constraint (`^0.1.0`).
- `app/` depends on **`zenpay_flutter`** (and `zenpay_embedded`) the same way.

**Why:** This repository is a unified Dart pub workspace (Melos drives the multi-package scripts on top of it — see the root [`pubspec.yaml`](../pubspec.yaml)). Every workspace member declares `resolution: workspace` in its own `pubspec.yaml`, so `dart pub get` at the root (`melos bs`) automatically resolves each of those ordinary version constraints to its local sibling package — a `path:` dependency is actually *rejected* once a package is a workspace member, since the workspace already provides that link.

Once published, external consumers resolve the exact same version constraint against pub.dev instead of the local workspace member — nothing in the constraint itself changes at release.

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
