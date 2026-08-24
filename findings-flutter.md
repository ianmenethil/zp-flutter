# zenpay_flutter — production release review (pub.dev)

Reviewed 2026-08-24 · version `0.1.0` · read-only, **no repo files modified**.
**Revision 4** — every finding re-verified by execution, by `pana` measurement, against official documentation, or against the TypeScript SDK at `F:\_ZP-Main\apps\HPP-TS\src\v6` (the source of truth for intended behaviour). Revision 3: one finding **REFUTED** (#5), one wording corrected (#2), and the blocker confirmed by execution *and* extended to iOS (which revision 1 never checked). **Revision 4 corrects revision 3's own fix recommendation for #1** — a per-source one-shot guard is insufficient, it must be process-wide — and adds the collection-equality trap to #3. Both corrections are marked in place below.

Method: 4 agents in two waves (review, then independent verification), cross-checked in the main session.

## Evidence key

| Grade | Meaning |
|---|---|
| **EXECUTED** | reproduced by running code against the real package this session |
| **MEASURED** | `pana` — the tool pub.dev actually runs — printed it this session |
| **SOURCE** | proven by reading the actual source on disk, quoted with line numbers |
| **DOC** | verified against official dart.dev / pub.dev docs or the pana/pub-dev source |
| **REFUTED** | claimed in revision 1, disproved by measurement |

## Verdict

**Packaging is clean — `pana` scores it 150 / 160**, losing points only on a missing `example/`. But there is **one release-blocking correctness bug**, now reproduced by a passing test, plus a confirmed dispose race. Fix #1 and #2 before publishing.

## pana — measured, not inferred

| Section | Score |
|---|---|
| Follow Dart file conventions | 30 / 30 |
| Provide documentation | **10 / 20** ← missing `example/` |
| Platform support | 20 / 20 (all 6 platforms, **WASM-ready**) |
| Pass static analysis | **50 / 50** — "no errors, warnings, lints, or formatting issues" |
| Up-to-date dependencies | 40 / 40 |
| **Total** | **150 / 160** |

Tags: `sdk:flutter`, all 6 `platform:*`, `is:null-safe`, `is:wasm-ready`, `is:dart3-compatible`, `license:apache-2.0`, `license:osi-approved`.

> ⚠️ `dart pub global activate pana` installs **0.23.18, which cannot run on Windows at all** (`sandbox_runner.dart:64-68` rejects any writable path containing `:`; every Windows temp path has a drive-letter colon — regression introduced in 0.23.17 per its own CHANGELOG). **SOURCE.** Numbers above are from **pana 0.23.16**. Pin 0.23.16 or run pana on Linux in CI.

## Commands run

| Command | Result |
|---|---|
| `flutter analyze` | **PASS** — "No issues found!" |
| `flutter test` | **PASS** — 34/34 |
| `flutter pub publish --dry-run` | **PASS — 0 warnings**, 30 KB archive |
| `dart format --output=none --set-exit-if-changed .` | **PASS** — 28 files, 0 changed |
| `flutter pub outdated` | **PASS** — "direct dependencies: all up-to-date" |
| `pana 0.23.16` | **150/160** |
| Reproduction project (`path:` dep, outside the repo) | `flutter test` → **+5 all passed** — findings #1a, #2, #5 reproduced |
| `curl https://github.com/ianmenethil/zp-flutter` | **HTTP 404** |

---

## 1. BLOCKER — a stale cold-start deep link is replayed into every later checkout · EXECUTED + SOURCE

`zenpay_flutter/lib/src/return_handling/mobile/app_links_return_uri_source.dart:53-64`

`AppLinksReturnUriSource.uris` is a **getter whose body is an `async*` generator**, so every new `.listen()` re-runs it and re-calls `_adapter.getInitialLink()`, yielding that value as the subscription's **first** item. `ZpCheckout.open()` subscribes once per call (`checkout_controller.dart:153-163`).

### Reproduced (this is no longer a prediction)

A throwaway test project with a fake `AppLinksPlatformAdapter` whose `getInitialLink()` always returns the same URI — exactly what the native cache does:

- Two `.listen()` calls on **one** `AppLinksReturnUriSource`: **both received the initial link**, `getInitialLinkCallCount == 2`.
- End-to-end: **one** `ZpCheckout`, `open()` called twice in sequence. The **second** call resolved `ZpReturnReceived` carrying **payment A's exact URI in under 50 ms**, with nothing ever emitted on `uriLinkStream` for payment B.

`flutter test` → `+5: All tests passed!`

### The native half — Android *and* iOS

**Android** (`app_links-7.2.1/android/.../AppLinksPlugin.java`, full 186-line file read; revision 1's citation `:45-46,79-80,169-170` verified exact):

```java
private String initialLink;                       // :45-46
} else if (call.method.equals("getInitialLink")) {
  result.success(initialLink);                    // :79-80 — returned unconditionally, every call
if (initialLink == null) { initialLink = dataString; }   // :169-170 — set once, never cleared
```

**iOS — new in this revision, revision 1 never checked it** (`AppLinksIosPlugin.swift`): `AppLinks.shared` is a **`static let` singleton** (line 6), `initialLink` (line 25) is set-once-never-cleared (256-259) and returned unconditionally at `handle()` case `"getInitialLink"` (67-68). **Same bug, arguably stickier** — it isn't even tied to engine attach/detach.

### Why it matters

A customer starts payment A, backgrounds or kills the app before returning. ZenPay redirects to the registered return link, cold-starting the app — the SDK's own documented flow. The first `open()` correctly consumes it. Later **in the same process**, the customer starts unrelated payment B; its `open()` replays A's URI, it still matches `expectedReturnUri` structurally (`return_validator.dart:32-39`), `ZpReturnValidator.validate` accepts it, and **B instantly resolves as a successful return carrying A's query** — before the customer has looked at B's tab. The merchant app cannot tell this from a genuine return.

Caused by the SDK, not caller misuse: it reproduces with the "one `ZpCheckout`, `open()` repeatedly" pattern the SDK's own design and reference app use (`example/app/.../checkout_page.dart:115,131-144`, commented "Every tap is an unrelated new ZenPay checkout attempt"), and **also with a fresh `AppLinksReturnUriSource` per attempt**, since the stale value lives in the native process-wide cache. The SDK deliberately doesn't correlate returns itself — sound policy, but it assumes a delivered return actually just happened.

**Scope:** mobile only. `WebPopupReturnUriSource.uris` (`web_popup_return_uri_source.dart:58-59`) returns the same broadcast stream on every access — no replay. **Not caught by tests:** `test/app_links_return_uri_source_test.dart` only ever subscribes once per instance.

### TS parity — **not** a port regression, but that does not excuse it

Checked against the TypeScript SDK at `F:\_ZP-Main\apps\HPP-TS\src\v6`, since a dropped safeguard would be the worst case. **The TS SDK does not correlate returns either** — no nonce, no state parameter, no session id, no `postMessage` correlation anywhere in `plugin/`. The only correlation primitive in the whole TS SDK, `createZpCallbackUrlToken`, is opt-in and scoped to the **server-to-server** `callbackUrl`, never the client return. So the Dart port did not lose anything here, and the `CLAUDE.md` "No Special-Casing `merchantUniquePaymentId`" policy is faithful to TS.

**But the threat models are not the same, which is why this stays a BLOCKER.** TS handles a **live HTTP redirect** inside a browser — the return arrives once, in the tab that initiated it, and cannot be re-delivered. The Dart SDK handles an **OS-cached deep link that the platform will replay on demand**, on both Android and iOS, for the life of the process. Uncorrelated validation is adequate for the first case and unsafe in the second. So the fix is Dart-side and does not require changing TS or introducing any return-correlation policy TS lacks.

### Correction to the fix recommendation (was wrong in revision 3)

Revision 3 recommended making the initial-link read "one-shot — consume it once **per source**". **That is insufficient**, and the reason is in this package:

```dart
ZpReturnUriSource createDefaultReturnUriSource() => AppLinksReturnUriSource();
```
`app_links_return_uri_source.dart:68` — the default factory returns a **brand-new instance on every call**.

So a per-instance guard only covers the pattern where one `ZpCheckout` (and therefore one source) is held across attempts. A consumer who constructs a fresh `ZpCheckout` per attempt — equally reasonable, and not discouraged anywhere in the API — gets a fresh `AppLinksReturnUriSource`, whose fresh per-instance guard is unset, and the native process-wide cache hands it the same stale link again. The guard has to be **process-wide** (static), not per-source, because the thing being consumed is a process-wide resource.

**That makes the fix a design decision, not a mechanical change.** At minimum it needs an answer to: which checkout is entitled to consume the single cold-start link, and what happens to a legitimate first-ever cold-start return that arrives before any `open()` has been called? Get that wrong and you suppress a real return instead of a stale one — trading a false positive for a false negative, which is worse in a payments flow. Recommend designing this explicitly and re-testing on a real device (cold-start via a return link, then start a second payment in the same running process), not just under `flutter test`.

## 2. HIGH — `dispose()` racing an in-flight `open()` · EXECUTED, with a wording correction

`zenpay_flutter/lib/src/checkout/checkout_controller.dart:116-206` · `active_checkout.dart:44-57`

`open()` never re-checks `_disposed`/`_active` after `await _presenter.openCheckout(...)`. Reproduced with an injected `CheckoutPresenter` (it is exported and injectable via `ZpCheckout(presenter: ...)`) whose `openCheckout()` hangs on a test-held `Completer`. Observed sequence:

1. `open()` suspends on `openCheckout()` — no browser open yet.
2. `dispose()` calls `_active.finish(ZpPresentationDismissed())` **synchronously**: the internal completer settles and `dismissCheckout()` fires immediately (`dismissCallCount` 0 → 1) — **before** `openCheckout()` resolves, so it no-ops against a browser that doesn't exist yet.
3. **Correction to revision 1's wording.** Revision 1 said the caller "gets a false outcome before any browser opened". That is true of the *internal* completer and the `dismissCheckout()` call, but **not** of what the caller can observe: the `Future` returned by `open()` is chained through the still-pending await, and provably does not resolve until `openCheckout()` does (`outcomeResolvedForCaller` still `false` a full microtask turn after `dispose()`). Precise statement: **internal state is corrupted immediately; the caller observes the false outcome only once the real presenter call completes** — near-simultaneous with the browser actually opening.
4. On completion, the caller receives `ZpPresentationDismissed` — a false signal; nothing was dismissed.
5. A genuine return emitted afterwards (both via the source and directly via `handleReturnUri`) produced **no outcome and no error** — `_active` is already null. **Silently dropped, confirmed.**
6. The presenter's own belated dismissal event was **unheard** — its subscription was already cancelled by `finish()`.
7. A second `dispose()` does not throw (idempotency intact).

**Net:** the bug is real and confirmed — false outcome, orphaned un-closable browser, dropped late return. A customer could complete a real payment in that dangling browser and the app would never learn of it. This is the ordinary "user navigates away while the browser is spinning up" case (e.g. `example/app/.../checkout_page.dart:283`). **Not caught by tests:** `tearDown` disposes only after each outcome has resolved.

## 3. MEDIUM — no `==`/`hashCode` on public models, contradicting the package's own rule · EXECUTED

Exact quote, `zenpay_flutter/CLAUDE.md` § "2. Flutter Strictness & Code Quality", item 3:

> **Immutability**:
>    - Flutter widgets should be `const` wherever possible to optimize the render tree.
>    - **Models should be immutable, overriding `==` and `hashCode`.**

Executed:
```dart
final a = ZpReturnReceived(returnUri: Uri.parse('https://app.example.com/return?x=1'));
final b = ZpReturnReceived(returnUri: Uri.parse('https://app.example.com/return?x=1'));
identical(a, b)         // false
a == b                  // false   <-- structurally identical, not equal
a.hashCode == b.hashCode// false
```

No override exists anywhere in `checkout_outcome.dart` (full file read). Affects exported field-carrying types `ZpReturnReceived`, `ZpLaunchFailed`, data-carrying `ZpCheckoutEvent` subclasses, `ZpCheckoutConfiguration`, `PresentationLaunchResult` — several already annotated `@immutable`.

Consumer impact: `expect(await outcome, ZpReturnReceived(returnUri: expectedUri))` spuriously fails; `Set`/`Map` dedup and `==`-based rebuild-avoidance (`ValueNotifier`/Bloc state) silently break on types documented as immutable. Not a functional bug in checkout execution — the SDK only switches on type internally — but a broken public contract against its own stated rule.

**Regression risk of fixing it is low, and specifically not the obvious one.** A concern worth ruling out is that internal code might rely on default identity equality, so adding value equality would coalesce two structurally-identical-but-distinct events. **That is already ruled out:** the SDK never compares these types by `==` anywhere — only by type, via `switch`. Verified by reading every consumer of them in `lib/`.

**The real trap is collection fields.** `ZpCheckoutConfiguration.allowedCheckoutHosts` is a `Set<String>` (`checkout_configuration.dart:103`), and **Dart's `Set`/`List` equality is identity, not structural** — so an `==` implementation that just compares `allowedCheckoutHosts` with `==` is silently useless: two configurations built from identical host lists would still compare unequal, and the override would look implemented while doing nothing. Correct implementations need element-wise comparison or `SetEquality` from `package:collection`, which is **not** currently a declared dependency of this package (deps are `app_links`, `flutter`, `meta`, `url_launcher`). Decide that before starting: hand-roll the comparison, or take the new dependency.

`ZpReturnReceived`/`ZpLaunchFailed`/`PresentationLaunchResult` have no collection fields, so those are straightforward. Whatever is added, the one-line proof is two structurally-identical instances asserting `==` and matching `hashCode`.

## 4. MEDIUM — `repository:` URL is unreachable (HTTP 404) · MEASURED + DOC

`zenpay_flutter/pubspec.yaml:5` → `https://github.com/ianmenethil/zp-flutter/tree/main/zenpay_flutter`

- `git ls-remote --heads origin` → only `refs/heads/master`.
- `curl https://github.com/ianmenethil/zp-flutter` → **HTTP 404 for the repository itself** (outbound HTTPS confirmed working against other GitHub URLs) — private, renamed, or removed.
- pana reports *"Repository URL doesn't exist … was unreachable"*, `"repositoryStatus": "inconclusive"`, and **deducts 0 points**.

**Revision 1's mechanism was wrong.** It claimed the wrong *branch* would make relative README links 404. pana's `check_repository.dart` clones the repo and **overwrites whatever branch the URL named** with the real default branch. **DOC.** What actually breaks links is verification failing outright — then `urlResolverFn` gets a null repository and **no rewriting happens at all** (`pub-dev`, `app/lib/package/models.dart`), so the README's relative links resolve against the pub.dev page URL. **Fixing `main` → `master` alone will not fix this** — the repository must be publicly reachable.

## 5. LOW — `analysis_options.yaml` reaches outside the package · **REFUTED as a score issue**

`zenpay_flutter/analysis_options.yaml:10` → `include: ../analysis_options.yaml`

**Revision 1 rated this HIGH and predicted a score deduction. Measurement disproved both halves** — pana scored **50/50**, "no errors, warnings, lints, or formatting issues":

- pana's `useAnalysisIncludes` defaults to **`false`** (`sdk_env.dart:179-181`), with no CLI flag, so it never passes the package's `include:` through — the analyzer it runs never tries to resolve `../analysis_options.yaml`. **SOURCE.**
- The formatting prediction also fails: pana only inherits a `formatter:` key declared as a direct top-level key of the package's own options file (which this package doesn't declare, so `page_width: 160` genuinely isn't inherited) — but the code already satisfies the 80-column default, so nothing is flagged.

The general rules revision 1 leaned on are real (warnings cap static analysis at 30/50; pana runs `dart format --set-exit-if-changed` and honours a locally-declared `page_width`) — **DOC** — they just don't fire here. **Residual:** `dart analyze` on the extracted archive does warn, so anyone opening the published package in an IDE sees it, and the root lint rules silently don't apply. Cosmetic.

## 6. LOW→**the only actual score deduction** — no `example/` directory · MEASURED

pana, verbatim: **`[x] 0/10 points: Package has an example`** — *"No example found."*

This is the entire 10-point gap between 150 and 160. **This package is the proof that README fences don't count:** its README has **five ` ```dart ` fences** (lines 49, 62, 81, 97, 143) and it lost the identical 10 points as `zenpay_dart`, which has none. pana looks only for literal files under `example/` and never inspects README content (`pana/lib/src/report/documentation.dart`, `maintenance.dart`). **SOURCE + MEASURED.** pub.dev's "Provide documentation" category is a hard split into two independently-scored 10-point subsections. **DOC.**

The monorepo's top-level `example/` app is confirmed absent from the publish archive, so it does not count. **Fix:** add `zenpay_flutter/example/`.

## 7. Note — `topics:` unused

Confirmed **not** a scored item on pub.dev. **DOC.** Discoverability only.

---

## Publish order & the `zenpay_dart` dependency

**There is no dependency edge between the two packages, so no publish-order constraint.** Checked because a `path:` dependency would block publication outright (**DOC**, dart.dev publishing docs):

- `zenpay_flutter/pubspec.yaml` `dependencies:` lists only `app_links`, `flutter` (sdk), `meta`, `url_launcher`. No `zenpay_dart` entry — direct, hosted, or path.
- `grep -r zenpay_dart zenpay_flutter/` matches prose only: `CLAUDE.md`, `README.md`, and one doc comment in `checkout_controller.dart` pointing integrators at `createZpCallbackUrlToken` for **their own backend**. No Dart imports.

`resolution: workspace` is a pub-workspaces marker, not a dependency edge, and does not block publish or affect consumers: pana strips `workspace`/`resolution` from the pubspec before analysing (`sdk_env.dart:660-661`; CHANGELOG 0.22.10) — **SOURCE + DOC** — and this package was scored 150/160 with the field left in place. Its only side effect is that `pub get` fails if you clone this subfolder alone with no workspace root above it.

## Dartdoc coverage — revision 1's number was wrong

- **Revision 1 said:** 31 exported symbols, 0 undocumented, 100%. That was **top-level symbols only**.
- **pana measured: 98 / 99 public API members documented (99.0%)** — it counts constructors, fields and accessors too.

Costs nothing either way (`[*] 10/10`, threshold is 20%). Corrected because revision 1's "100%" would mislead.

## Verified clean

**Security boundary — this is the part that matters most, and it holds**
- Return-URI validation (`return_validator.dart`, `web_return_validation.dart`, `web_return_message.dart`): scheme/host/port/path compared exactly and case-normalised where appropriate; `userInfo`/`fragment` must be empty; length bounds on the whole URI **and** each query value; duplicate query keys rejected; malformed percent-encoding rejected. **SOURCE**
- Web `postMessage` receiver checks `event.origin` (browser-supplied, unspoofable) against the page's own `location.origin` — **never `'*'`** — before touching the payload, and validates the `zenpay:checkout-return:` shape before parsing a URI. The sender only relays if its own location already matches `expectedReturnUri`, and posts with `targetOrigin` pinned to that origin. A crafted or cross-origin message cannot fabricate a successful return. **SOURCE**
- Launch validation (`launch_validator.dart`): HTTPS-only, port 443, no credentials, no fragment, length cap, host allowlist — and `open()` runs it before any presenter call. **SOURCE**

**State machine & platform split**
- `ActiveCheckout.finish()` is guarded by `_completer.isCompleted` — a timeout racing a return or dismissal cannot double-settle. Subscriptions and the timeout timer cancel together with settlement on every path. **SOURCE** (dispose ordering is #2)
- Conditional imports gate correctly on `dart.library.js_interop`; `dart:js_interop`-touching files are reachable only through them, never from a shared or mobile path. `web_return_validation.dart`/`web_return_message.dart` are deliberately free of `dart:js_interop` so they run under the VM. **SOURCE** — and pana awards all 6 platforms plus WASM-ready. **MEASURED**

**API surface & error contract**
- No internal type leaks: `ZpLaunchValidator`/`ZpReturnValidator` not exported (only the `isAllowedCheckoutUrl` predicate, deliberately); factory internals imported `as impl` not re-exported. `testing.dart` exports only `FakeReturnUriSource` from a separate entrypoint. **SOURCE**
- The two files both named `checkout_event.dart` (`exceptions/` vs `observability/`) are unrelated sealed hierarchies — `ZpCheckoutException` vs `ZpCheckoutEvent`. No collision, no duplication. **Not a defect.**
- `open()` throws only the three documented `ZpCheckoutException` subclasses; `url_launcher` platform errors map to `ZpLaunchFailed`/`mapLaunchFailureCode`. Observer callbacks swallow observer exceptions. **SOURCE**
- **No sensitive data leaks:** no `print`/`debugPrint` anywhere in `lib/`; events carry only host names, enum reasons, outcome names and durations — never a full checkout URL or return query. **SOURCE**

**Packaging** (**MEASURED** by pana unless noted)
- `[*] 10/10` OSI licence — Apache-2.0, real file inside the package, present in the archive.
- `[*] 5/5` README · `[*] 5/5` CHANGELOG (top entry `## 0.1.0` matches pubspec).
- `[*] 40/40` dependencies — `app_links ^7.2.1`, `meta ^1.18.0`, `url_launcher ^6.3.2` all up to date, all official Dart/Flutter-team packages, normal caret constraints, no git or unbounded deps; `pub downgrade` exposes no error at lower bounds.
- No `platforms:` block — correct, this is not a Flutter plugin (no `flutter: plugin:` section); pub.dev infers platforms from analysis, and awarded all 6.
- `.pubignore` excludes `CLAUDE.md`/`AGENTS.md`; no internal docs, secrets or `.env` in the archive.
- README public-API snippets compile — verified in a throwaway external consumer project. (`ZpCheckout`'s `required this._returnUriSource` is exposed to callers as `returnUriSource` by Dart's initializing-formal rule — both spellings tested; the README is correct.) **EXECUTED**
- `description` 65 chars, inside the documented 60–180 band. **DOC**

## TypeScript SDK parity — `F:\_ZP-Main\apps\HPP-TS\src\v6`

| Question | Verdict |
|---|---|
| Return correlation / replay protection | **TS does not correlate either** — no nonce, state, session id, or `postMessage` correlation in `plugin/`. The Dart port dropped nothing; see the analysis under finding #1 for why the blocker still stands (live redirect vs. OS-replayable deep link). |
| Launch-URL construction & host allowlisting | No divergence found that clears the evidence bar. |

The only genuine port regression across both packages is in `zenpay_dart` (NaN/Infinity payment amount) — see that report.

## Still open

- **The native cache persisting across a real running process** (finding #1's native half) is proven by reading Android and iOS plugin source, not by running on a device. An on-device confirmation: cold-start the app via a return link, then start a second payment in the same session. Everything else in #1 was executed.
- **pana on Windows** — numbers are from 0.23.16 because 0.23.18 cannot run here; a Linux CI run on latest pana would confirm 150/160 independently.
- TypeScript reference-SDK parity — deliberately out of scope.

## Working tree note

No file under `zenpay_flutter/` changed at any point during this review (`git status --porcelain -- zenpay_flutter/` empty before and after). Files elsewhere in the repo (root `README.md`, `cli.dart`, `example/**`, `scripts/**`, `zenpay_dart/README.md`) changed in the same window — not by this review, which modified nothing.
