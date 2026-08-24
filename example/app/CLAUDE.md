# example/app — Reference Flutter Client

Reference Flutter client for the combined ZenPay example: fetches a checkout session from `example/backend`, presents ZenPay Hosted Checkout via `zenpay_flutter`, and handles the return. It is a *reference implementation*, not a library — merchants copy the pattern, not the package.

---

## Related Guides

- **[Combined Example](../CLAUDE.md)** — Two-app architecture, how this app and `example/backend` fit together.
- **[zenpay_flutter](../../zenpay_flutter/CLAUDE.md)** — The SDK this app depends on (`../../zenpay_flutter` via Melos `path:`) for checkout presentation and return handling.
- **[example/backend](../backend/CLAUDE.md)** — The server this app fetches sessions from.

---

## 1. Scope & Responsibilities

- `lib/features/checkout/services/checkout_service.dart` talks only to `example/backend`'s two-step checkout flow (`POST /api/v1/checkout/token` to prepare, `POST /api/v1/checkout/exchange` for the checkout URL) plus `GET /api/v1/sessions` for status, all over `http`. It never builds a checkout URL, never touches ZenPay credentials, and never calls ZenPay directly — see `zenpay_flutter`'s own scope rule for why: URL construction and payment confirmation are the backend's job.
- `lib/features/checkout/ui/checkout_page.dart` and its widgets are demonstration UI only — presentation choices here (colors, layout, copy) are not SDK requirements. Do not invent or extend the UI/visual design beyond what the project owner has specified; see [example/CLAUDE.md § Look and Feel](../CLAUDE.md).
- `lib/features/checkout/models/checkout_modes.dart` and `mock_customer.dart` model the demo's own request shapes; they are not part of any SDK's public API surface.
- `lib/previews/checkout_widgets_previews.dart` uses Flutter's widget preview system — keep it in sync when adding new checkout widgets.
- Treat any `ZpCheckoutOutcome` returned by `zenpay_flutter` as provisional. This app must always confirm final status against `example/backend`'s session-status endpoint before showing a success state.

## 2. Flutter Strictness & Code Quality

Adhere to [analysis_options.yaml](analysis_options.yaml): strict casts/inference/raw-types, `const` widgets wherever possible, comprehensive doc comments on any exported symbol.

## 3. Verification Commands

Part of the root Melos monorepo. Run from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run test
```

To run the app itself, use `dart run cli.dart --android` / `--ios` / `--web` from the repo root — `example/backend` must already be running (`dart run cli.dart --server`).
