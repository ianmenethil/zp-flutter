---
name: zenpay-demo-app
description: >-
  Builds a complete, runnable ZenPay Hosted Checkout demo from a one-line product
  description — a Shelf backend using zenpay_dart plus a Flutter client using
  zenpay_flutter, wired end to end, Android first and web second. Use this whenever
  someone wants to see the ZenPay SDKs working together, says "build a demo app",
  "scaffold a new example", "make an app that takes payments", "show me how to
  integrate ZenPay", "build a coffee shop / donation / booking app with checkout",
  or has just cloned this repo and wants something running. Also use it when someone
  is hand-writing ZenPay integration code from scratch — the scaffold already solves
  the wiring they are about to get wrong.
---

# Build a ZenPay demo app

Turn a product idea ("a coffee shop ordering app") into a running integration: a backend
that mints checkout URLs with `zenpay_dart` and verifies ZenPay's signed callback, and a
Flutter app that presents checkout with `zenpay_flutter` and confirms the result.

The product half is yours to design. The integration half is not open to interpretation —
it is a specific contract with specific failure modes, and it is where a from-scratch
attempt loses an afternoon. `scripts/new_demo_app.dart` owns every mechanical part of that
contract so you can spend your turns on the product.

## Pick a mode first

| Mode | Generates | Demonstrates | Use when |
|---|---|---|---|
| `full` (default) | `<name>_backend` + `<name>_app` | both SDKs | the point is to show the integration |
| `client` | `<name>_app` only, pointed at the running `example/backend` | `zenpay_flutter` only | someone only wants a client, fast |

Ask which if the request is ambiguous. "Show me how ZenPay works" means `full` — in `client`
mode `zenpay_dart` never appears in the generated code at all.

## Build loop

1. **Understand the product — then build, don't interview.** "1-shot" means the person
   describes a product and gets a running app; a round of questions first breaks that
   promise. Infer the screens, the copy, and the look from the description and go.

   Stop for exactly one thing: **the transaction mode**, when the product genuinely does not
   imply one. A coffee shop is a fixed charge (`0`). A donation page is a customer-entered
   amount (`2`). "A payments app" is neither, and guessing costs a rewrite rather than a
   tweak — every other wrong guess is cheap to fix once they can see it. See
   `references/integration-contract.md` § Modes.

   The demo's visual design is yours to invent. `example/CLAUDE.md` § 3 forbids inventing UI,
   but that governs `example/app` — the reference integration the project owner specified.
   A generated demo is a throwaway teaching artifact, so make a coffee shop look like a
   coffee shop. Only the integration is fixed; the product around it is not.
2. **Scaffold.** `dart run .claude/skills/zenpay-demo-app/scripts/new_demo_app.dart --name <snake_name> [--mode client] [--committed]`
   This writes both packages, registers them in the root pub workspace, seeds `.env` files
   from the existing example, picks a free port, and prints the next command. It is
   idempotent — re-running against an existing name refuses rather than clobbering.
3. **Write the backend** (skip in `client` mode) — `references/backend-wiring.md`. Four
   `zenpay_dart` calls carry the whole integration. Everything else is your product.
4. **Write the app** — `references/client-wiring.md`. Build the product screens, then the
   pay handler. The pay handler has a required *ordering*, not just required calls.
5. **Verify** — run the commands in § Verification below. They fail loudly on the wiring
   mistakes; they cannot prove the payment itself works (see that section).
6. **Offer a review.** Say what `verify_demo_app.dart` covered, then offer the
   `zenpay-integration-reviewer` agent (`agents/zenpay-integration-reviewer.md`) — do not
   spawn it unasked. It reads for the three mistakes that pass every compiler and every
   test: provisional status shown as success, `reserveLaunch()` after an `await`, and
   credentials reachable from client code. You wrote the code, so you are the worst judge
   of whether it has them — say that plainly when offering, rather than presenting the
   review as optional polish.

## What the generated code must get right

These are not style preferences. Each one is a payment bug that ships silently.

**A return is not a payment.** `redirectUrl` and `callbackUrl` are two independent channels
handed to ZenPay at launch. The browser redirect always fires and exists for UI/UX; only the
signed server-to-server callback — verified by `verifyZpCallback`'s constant-time
`ValidationCode` check — says whether money moved. Any success UI must come from a backend
status lookup, never from `ZpCheckoutOutcome` alone. Expect the first lookup to come back
unverified and poll; that is ordinary, not an error. This is the single most common way a
demo integration is wrong while looking completely correct.

**A rejected callback is gone.** ZenPay does not retry, so every non-2xx your webhook route
returns permanently discards that payment's status. Reject a bad signature; think hard before
rejecting anything else.

**One mode per demo.** Build the transaction mode the product implies, not the four-way
picker `example/app` ships — that exists because it is the reference for the whole SDK, not
because a merchant would offer it.

**The browser decides when you may open a tab.** On web, `reserveLaunch()` has to run
synchronously inside the click handler, before the first `await`. Ask for the checkout URL
first and the popup is blocked — and it fails only on web, only in a real browser, so
nothing in your test run catches it.

**Credentials belong to one process.** `zenpay_dart` handles the merchant password and the
HMAC secret; importing it from Flutter code puts both in a binary you hand to customers.
The app talks to your backend over HTTP and never to ZenPay directly.

**The default presenter is the safer architecture, not just the older one.** Custom Tabs and
`SFSafariViewController` render checkout in the OS browser process, where the app holds no
handle to the page at all. Do not reach for `zenpay_embedded` unless the request explicitly
calls for in-app WebView presentation — and read [PCI_SAQ_A.md](../../../PCI_SAQ_A.md) § 3
first if it does.

## Gotchas

The highest-signal part of this skill, and the shortest — because it is grown, not designed.
**Every time a build trips on something, add a line here.** A gotcha discovered twice is a
gotcha that was never written down the first time.

- `melos`'s `packages:` glob is `example/*` — **direct children only**. Nested packages like
  `example/coffee/backend` are silently invisible to every `melos run` script, which is why
  generated packages are flat (`example/coffee_backend`).
- `dart create -t console` adds a `path: ^1.9.0` dependency the demo does not use. Harmless,
  but `melos run lint` (dart_code_linter) may flag it if the package ever declares that lint.
- The scaffold's own tests live outside any package, so `melos run test` never reaches them.
  Run `dart test .claude/skills/zenpay-demo-app/scripts/new_demo_app_test.dart` directly.
- `verify_demo_app.dart`'s `reserveLaunch()` check is a line scan, not an AST walk. An
  `await` hidden inside a helper called before `reserveLaunch()` passes the check and still
  blocks the popup. If that bites, the fix is `package:analyzer`, not a cleverer regex.

## References

Read the one you need, when you need it.

- **`references/integration-contract.md`** — endpoints, headers, request/response shapes,
  transaction modes, status semantics. Read before writing either half.
- **`references/client-wiring.md`** — `ZpCheckout` setup, the pay handler's ordering, return
  handling, outcome mapping, the web-vs-mobile diff. Read before writing the app.
- **`references/backend-wiring.md`** — the four `zenpay_dart` calls, `.env` variables, what
  `example/backend` does that a demo does not need. Read before writing the backend.
- **`references/repo-conventions.md`** — workspace rules, analysis strictness, the CLAUDE.md
  contract, lefthook gates. Read before committing anything.

## Verification

```bash
melos bs
melos run analyze
melos run test
dart run .claude/skills/zenpay-demo-app/scripts/verify_demo_app.dart <name>
```

`verify_demo_app.dart` checks the wiring invariants against the generated source — workspace
registration, no `zenpay_dart` import in app code, `reserveLaunch()` ordering, a status
lookup on the return path. It asserts against the live repo rather than restating it, so it
fails when the repo moves instead of quietly going stale.

Then the live check, two terminals:

```bash
dart run cli.dart --server
```
```bash
dart run cli.dart --android
```

Tap Pay. Landing on ZenPay's hosted sandbox page means steps 1–5 are wired correctly.

**What this cannot prove.** Everything past that page needs real sandbox credentials in
`example/backend/.env`, and the full round trip — a verified callback — needs a public HTTPS
URL ZenPay's servers can reach (`dart run cli.dart --quick-tunnel`). A green verify run means
the integration is wired, not that a payment succeeds. Say so plainly rather than reporting
a working payment flow you did not observe.
