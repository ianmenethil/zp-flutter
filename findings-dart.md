# zenpay_dart — production release review (pub.dev)

Reviewed 2026-08-24 · version `0.1.0` · review phases were read-only; **revision 4 applied fixes** - see "Status after fixes" for which files changed.
**Revision 4** — every finding has now been re-verified by execution, by `pana` measurement, against official documentation, or against the TypeScript SDK at `F:\_ZP-Main\apps\HPP-TS\src\v6` (the source of truth for intended behaviour). Changes from revision 1, marked in place rather than quietly dropped: **finding #4 REFUTED** (both of its claims — the analyzer warning and the formatting failure); **finding #3's mechanism refuted** but the finding itself stands on a different and worse cause; **#1 lowered** HIGH → MEDIUM; **#5 raised** from LOW to the only actual score deduction; the dartdoc coverage figure corrected; the `constantTimeHexEqual` clean claim narrowed; **#2 newly identified as a port regression** against the TS SDK.

Method: 4 agents in two waves (review, then independent verification), cross-checked in the main session.

## Evidence key

| Grade | Meaning |
|---|---|
| **MEASURED** | `pana` — the tool pub.dev actually runs — printed it this session |
| **EXECUTED** | reproduced by running code against the real package this session |
| **SOURCE** | proven by reading the actual source/changelog on disk, quoted |
| **DOC** | verified against official dart.dev / pub.dev documentation or the pana/pub-dev source |
| **REFUTED** | claimed in revision 1, disproved by measurement |
| **CANNOT VERIFY** | genuinely open; what would close it is stated |

## Status after fixes (2026-08-24)

**`pana` now scores it 160 / 160.** Three of the six findings are closed; one is partly closed pending an action only you can take; one awaits a design decision; one is deferred.

| # | Finding | Status |
|---|---|---|
| 1 | `merchantCode` path splicing | **OPEN** — awaiting a decision on the guard; 5 tests red |
| 2 | non-finite `paymentAmount` | **FIXED** — 3 tests now green |
| 3 | `repository:` URL | **PARTIAL** — branch corrected `main`→`master`; still 404s because the GitHub repo is not public |
| 4 | `analysis_options.yaml` include | **OPEN** — the fix needs a dependency decision, see below |
| 5 | no `example/` | **FIXED** — recovered the 10 points |
| 6 | commit before publishing | deferred to you |

Regression net after the changes: `dart analyze` clean · `dart format` clean · **72 tests pass, 5 fail** (the 5 are finding #1's, red by design — see [known_defects_test.dart](zenpay_dart/test/known_defects_test.dart)). No pre-existing test broke; the suite went 65 → 72 passing.

## pana — measured, not inferred

| Section | Before | After |
|---|---|---|
| Follow Dart file conventions | 30 / 30 | 30 / 30 |
| Provide documentation | **10 / 20** ← no `example/` | **20 / 20** |
| Platform support | 20 / 20 (all 6, WASM-ready) | 20 / 20 |
| Pass static analysis | 50 / 50 | 50 / 50 |
| Up-to-date dependencies | 40 / 40 | 40 / 40 |
| **Total** | **150 / 160** | **160 / 160** |

`[*] 10/10 points: Package has an example` — verbatim, after adding [example/main.dart](zenpay_dart/example/main.dart) and [example/README.md](zenpay_dart/example/README.md). The pubspec section stays `[~]` ("Repository URL doesn't exist") at no point cost; see #3.

Tags awarded: `sdk:dart`, `sdk:flutter`, all 6 `platform:*`, `runtime:native-aot/jit/web`, `is:null-safe`, `is:wasm-ready`, `is:dart3-compatible`, `license:apache-2.0`, `license:osi-approved`.

> ⚠️ **Toolchain note worth knowing:** `dart pub global activate pana` installs **0.23.18, which cannot run at all on Windows.** It throws `Invalid argument (outputFolder): Sandbox output folder must not contain ":"` — `sandbox_runner.dart:64-68` rejects any writable path containing `:`, and every Windows temp path has a drive-letter colon. Introduced in 0.23.17 per its own CHANGELOG. **SOURCE.** All numbers above are from **pana 0.23.16**, run against a copy of the package outside any git repo. If you want these numbers in CI, pin 0.23.16 or run pana on Linux.

## Commands run

| Command | Result |
|---|---|
| `dart analyze` (in monorepo) | **PASS** — "No issues found!" |
| `dart test` (before fixes) | **PASS** — 65/65 |
| `dart test` (after fixes) | 72 pass, 5 fail — the 5 are #1's, red by design |
| `dart format --output=none --set-exit-if-changed .` | **PASS** — 18 files, 0 changed |
| `dart pub publish --dry-run` | **PASS**, 1 warning (uncommitted `README.md`) — 31 KB archive |
| `dart doc --dry-run .` | **PASS** — 0 warnings, 0 errors |
| `pana 0.23.16` (before) | **150/160** |
| `pana 0.23.16` (after adding `example/`) | **160/160** |
| `dart analyze .` on the package extracted standalone | 1 warning — `include_file_not_found` (see #4) |
| `git ls-remote --heads origin` | only `refs/heads/master` |
| `curl https://github.com/ianmenethil/zp-flutter` | **HTTP 404** |
| Reproduction project (`path:` dep, outside the repo) | findings #1 and #2 reproduced |
| `curl .../tree/master/zenpay_dart` (after branch fix) | **HTTP 404** — the repo itself is not public |
| `dart run example/main.dart` | **PASS** — full flow runs end to end |

---

## 1. MEDIUM — `merchantCode` is spliced into the URL path unvalidated · EXECUTED

`zenpay_dart/lib/src/checkout_url.dart:165-168`

`base.replace(path: '$basePath/${request.merchantCode}/...')` treats the interpolated string as a **raw path**, so a literal `/` is a segment separator, and `..` is resolved by `Uri`'s RFC 3986 dot-segment removal. `validateZpCheckoutUrlRequest` (`:54-90`) only rejects an empty value.

Reproduced independently, twice, against the real public `createZpCheckoutUrl`. **All ten inputs returned `ZpUrlSuccess`** — none rejected:

| `merchantCode` | Resulting path |
|---|---|
| `Zen/Test` | `/Online/v5/Zen/Test/Authorise` — split into two segments |
| `..` | `/Online/Authorise` — one level consumed |
| `../..` | `/Authorise` — both `/Online/v5` segments gone |
| `../../etc` | `/etc/Authorise` — **API-version prefix fully replaced** |
| `ZenTrailing/` | `/Online/v5/ZenTrailing//Authorise` — double slash |
| `Zen Test`, `Zen?x=1`, `Zen#frag`, `Zen\r\nCode` | percent-encoded — harmless |

**Why MEDIUM and not HIGH (revision 1 said HIGH — corrected):** `base.replace(path:, query:)` only replaces path and query. **Scheme, host and port are untouched**, and `request.url` is itself regex-validated against `ZpPatterns.hcpEndpoint` (6 known ZenPay hostnames). So this is **not** an open redirect or SSRF — the worst case is a malformed request to ZenPay's own already-validated domain. `merchantCode` is also server-side merchant configuration (the file's own doc: "Never import this file from a Flutter mobile app or frontend package"), not end-user input.

Two facts that sharpen the framing:
- `merchantCode` is **not** singled out for weaker validation. `apiKey`, `fingerprint` and `merchantCode` all get only `.isEmpty` checks; `url` and `customerEmail` are regex-validated. What singles out `merchantCode` is that it alone lands in the **path** — `apiKey`/`fingerprint` go through `_buildQueryParams` (`:95-96`) where `Uri.encodeQueryComponent` makes a `/` inert.
- No format constraint for `merchantCode` is documented anywhere in the package (grepped all dartdoc + README) — only "Merchant identifier used in the Authorise URL path" (`checkout_options.dart:22`).

**Recommended fix — a single-path-segment guard, not a charset regex.** Build the URL, then reject if `merchantCode` did not survive as exactly one path segment. This invents no charset, so nothing currently working can break: the only inputs it rejects are ones already producing a wrong URL. A charset allow-list was considered and rejected — it could refuse a live merchant code for no observed reason.

In one sentence: **check that the merchant code still sits in exactly one slot of the URL path, and refuse it if it slipped into more than one.**

The 5 red tests in `known_defects_test.dart` assert this as an *invariant* (reject the input, or keep it in one segment) rather than as a charset policy, so any correct implementation turns them green without editing the tests.

**TS parity — TS has the same gap, so this is not a port regression.** The TypeScript SDK's URL builder (`F:\_ZP-Main\apps\HPP-TS\src\v6\...\generate-url.ts:49-59,132-140`) also never validates the merchant-code charset and also uses raw string concatenation rather than `URL`. Its only merchantCode check is non-empty *and only when the URL ends in `v4`* (`generate-url.ts:49-59`; `plugin/core/constants.ts:148` defines `URL_SUFFIX_V4` and no v5 equivalent) — so for a v5 URL, current production, **TS performs no merchantCode check at all**, while Dart's emptiness check is unconditional. Dart is already stricter.

**Consequence for the fix: it is a deliberate divergence from TS, and TS cannot be changed to match** — that repo is read-only for this work. Dart will reject inputs TS accepts. That is the tradeoff to accept or decline; the alternative is shipping a demonstrated defect. Severity stays **MEDIUM**. The TS-side issues are recorded as findings for whoever owns that repo, not actioned here.

**`Zen%2FTest` — resolved, no longer open.** `merchantCode = "Zen%2FTest"` passes through **byte-for-byte unchanged** (Dart does not re-escape `%` to `%25`, because `%2F` already looks like a valid triplet). Verified by **running both builders**: the TS SDK emits the identical string. So Dart matches TS exactly and this is not a Dart-side defect. ZenPay's server-side decoding of a raw `%2F` is still unverified (that needs a live call, not authorized) — but whatever it does, the production TS SDK has been behaving the same way.

## 2. MEDIUM — NaN/Infinity `paymentAmount` throws an undocumented exception type · EXECUTED · **PORT REGRESSION** · **FIXED**

> **Fixed 2026-08-24.** `_isAmountShaped` (`callback_token.dart:49`) now requires a *finite* num, the `ArgumentError` message reads "must be a String or a finite num", and the dartdoc states the NaN/Infinity rejection explicitly. This restores exact TS parity (`z.number()` semantics) — no divergence, no new behaviour beyond what the doc already promised. The 3 previously-red tests in `known_defects_test.dart` are now green.

`zenpay_dart/lib/src/callback_token.dart:49` and `:113`

```dart
bool _isAmountShaped(Object? value) => value == null || value is String || value is num;
```

`double.nan` and `double.infinity` are `num`, so they pass and reach `jsonEncode(wire)`. Reproduced:

```
paymentAmount: double.nan               -> JsonUnsupportedObjectError ... NaN        | is ArgumentError: false
paymentAmount: double.infinity          -> JsonUnsupportedObjectError ... Infinity   | is ArgumentError: false
paymentAmount: double.negativeInfinity  -> JsonUnsupportedObjectError ... -Infinity  | is ArgumentError: false
```

The dartdoc promises `ArgumentError` for "a non-`String`/non-`num` `paymentAmount`". NaN/Infinity *do* satisfy the doc's literal "is num" test, so this is an undocumented gap in the contract rather than a contradiction of a stated promise. Either way, a caller catching `ArgumentError` per the documented contract gets an unhandled exception type — e.g. an accidental division producing `NaN` flowing into `paymentAmount`.

**TS parity — this is a genuine port regression, and it is the only one found.** The TypeScript SDK rejects NaN/Infinity cleanly at the schema boundary: its Zod schema (`F:\_ZP-Main\apps\HPP-TS\src\v6\...\callbackurl-token.ts:279-284`) throws a clean `TypeError` for them. Verified by execution against the project's actual installed `zod@^4.4.3` — `z.number()` rejects both. The Dart port replaced that schema with a hand-written `_isAmountShaped` type check and **lost the finiteness guard**. Fixing it restores TS behaviour rather than inventing new behaviour: reject non-finite `num` in the validator with the documented `ArgumentError`.

## 3. MEDIUM — `repository:` URL is unreachable (HTTP 404) · MEASURED + DOC · **PARTIALLY FIXED**

> **Partially fixed 2026-08-24.** The branch is corrected to `master` (it was verifiably wrong — the remote has no `main`). **The URL still returns 404**, re-checked live after the change: `https://github.com/ianmenethil/zp-flutter/tree/master/zenpay_dart` → `404`. The repository itself is not publicly reachable, so no pubspec edit can clear this — it needs the GitHub repo made public (or the field pointed at wherever the public mirror lives). **Only you can do that.** Cost while unresolved: 0 pana points, but a dead Repository link on the package page and no relative-link rewriting in the README.

`zenpay_dart/pubspec.yaml:5` → `https://github.com/ianmenethil/zp-flutter/tree/main/zenpay_dart`

**Revision 1 framed this as a branch typo. That was incomplete.** Verified this session:
- `git ls-remote --heads origin` → only `refs/heads/master`; no `main`.
- `curl https://github.com/ianmenethil/zp-flutter` → **HTTP 404 for the repository itself**, not just the branch. Outbound HTTPS from the sandbox was confirmed working against other GitHub URLs, so this is a real 404 — the repo is private, renamed, or removed.
- pana reports it: *"Repository URL doesn't exist. At the time of the analysis `…` was unreachable."* JSON `"repositoryStatus": "inconclusive"`. **It deducts 0 points** and keeps 10/10 on the pubspec section.

**Also corrected:** revision 1 claimed the wrong *branch* would make relative README links 404. That mechanism is wrong — pana's `check_repository.dart` clones the repo and **overwrites whatever branch the URL named** with the real default branch (`branch = await repo.detectDefaultBranch()`). **DOC.**

What actually happens is worse in a different way: when repository verification **fails entirely** (as it does here, 404), `urlResolverFn` gets a null repository and **no relative-link rewriting happens at all** (`pub-dev`, `app/lib/package/models.dart`) — so the README's relative links resolve against the pub.dev page URL and break. **So fixing `main` → `master` alone will not fix this.** The repository must be publicly reachable at the URL given.

## 4. LOW — `analysis_options.yaml` reaches outside the package · **REFUTED as a score issue** · OPEN, needs a decision

> **Update: the fix is not what revision 3 proposed, because the include chain has *two* broken links.**
>
> `zenpay_dart/analysis_options.yaml:10` includes `../analysis_options.yaml`, and that root file in turn does `include: package:very_good_analysis/analysis_options.yaml`. **`very_good_analysis` is declared only in the *root* pubspec's `dev_dependencies`** (root `pubspec.yaml`), not in `zenpay_dart`'s — it resolves today purely because the pub workspace shares one `package_config.json`. In an extracted archive, both the `../` hop and the `package:` hop fail.
>
> So "inline the settings or restate `page_width` locally" is not sufficient. The options are:
>
> 1. **Add `very_good_analysis` to `zenpay_dart`'s `dev_dependencies`** and point `include:` straight at `package:very_good_analysis/analysis_options.yaml`, restating the root's three local overrides (`formatter: page_width: 160`, `lines_longer_than_80_chars: false`, `one_member_abstracts: false`). Self-contained, no rule duplication, and a dev_dependency ships nothing to consumers. **Costs one new dev_dependency.**
> 2. **Drop the include and inline only the rules you want.** No new dependency, but it abandons `very_good_analysis` and its rule set — weaker linting, and it will drift from the rest of the monorepo.
> 3. **Leave it.** Measured cost is **zero pana points** (160/160 was achieved with the include still in place). The only symptom is an `include_file_not_found` warning for someone who opens the *published archive* in an IDE.
>
> Recommend **1** if you want it clean, **3** if you want it untouched. Not doing either silently.

`zenpay_dart/analysis_options.yaml:10` → `include: ../analysis_options.yaml`

**Revision 1 rated this HIGH and predicted it would cost pub.dev points. Measurement disproved both halves:**

- **Claimed:** an `include_file_not_found` warning costs 20 of 50 static-analysis points. **REFUTED** — pana scored **50/50**, "code has no errors, warnings, lints, or formatting issues", zero itemized issues. Reason, from pana's source: `useAnalysisIncludes` defaults to **`false`** (`sdk_env.dart:179-181`) with no CLI flag to enable it, so pana never passes the package's `include:` through and the analyzer it runs never tries to resolve `../analysis_options.yaml`. **SOURCE.**
- **Claimed:** formatting would fall back to 80 columns and fail. **REFUTED** — pana reported no formatting issues. The premise is directionally right (pana only inherits a `formatter:` key declared as a direct top-level key of the package's *own* options file, which neither package declares, so `page_width: 160` genuinely is not inherited) — but the code already satisfies the 80-column default, so nothing fails.

For completeness, the general rules revision 1 relied on *are* real — analyzer warnings do cap static analysis at 30/50, and pana does run `dart format --set-exit-if-changed` and does honour a locally-declared `formatter: page_width:` (**DOC**, from `pana/lib/src/report/static_analysis.dart` and `analysis_options.dart`). They just don't fire here.

**Residual, genuinely observed:** `dart analyze` on the extracted archive *does* warn (`include_file_not_found`) — I ran it. So anyone who downloads the published package and opens it in an IDE sees that warning, and the root file's lint rules silently don't apply. Cosmetic. Worth a one-line fix; not worth blocking a release.

## 5. LOW→**the only actual score deduction** — no `example/` directory · MEASURED · **FIXED**

> **Fixed 2026-08-24.** Added `example/main.dart` (runs end to end: fingerprint → Authorise URL → callback verification, verified with `dart run example/main.dart`) and `example/README.md`. pana now reports `[*] 10/10 points: Package has an example` and the package scores **160/160**. The example deliberately demonstrates the *rejection* path with a well-formed but wrong 128-hex `validationCode`, so no valid digest is hardcoded.

pana, verbatim: **`[x] 0/10 points: Package has an example`** — *"No example found."* / *"See package layout guidelines on how to add an example."*

This is the **entire** 10-point gap between 150 and 160. Confirmed against pub.dev's documented scoring: the "Provide documentation" category is a hard split into two independently-scored 10-point subsections — illustrative example, and ≥20% dartdoc coverage (**DOC**, `pana/lib/src/report/documentation.dart`).

**Mechanism correction:** revision 1 implied README Dart code fences would satisfy this. They do not. pana looks **only** for literal files under `example/` (`example/README.md`, `example/lib/main.dart`, `example/<pkg>.dart`, …) and never inspects README content. Proven by counter-example: `zenpay_flutter`'s README has five ` ```dart ` fences and lost the identical 10 points. **SOURCE + MEASURED.**

**Fix:** add `zenpay_dart/example/` with a runnable snippet. This is the single highest-value change in this report for the pub.dev score.

## 6. Housekeeping — commit before publishing

`dart pub publish --dry-run` warns that `README.md` is modified in the working tree. Publish from a clean, tagged commit.

---

## Dartdoc coverage — revision 1's number was wrong

- **Revision 1 said:** 42 exported symbols, 0 undocumented, 100%. That was **top-level symbols only**.
- **pana measured:** **145 / 156 public API members documented (92.9%)** — it counts constructors, fields and accessors too, and named a short list of undocumented constructors.

Both are true at their own granularity, but pana's is the one pub.dev shows. 92.9% is far above the 20% threshold, so **it costs nothing** (`[*] 10/10`). Stated here only because revision 1's "100%" would have been misleading if you'd relied on it.

## Verified clean

**Cryptography**
- SHA3-512 hash-pipe field order and delimiters match independently-computed golden vectors in `test/fixtures/zp_hcp_v0_1_30_vectors.json`; all golden tests pass. **EXECUTED**
- `constantTimeHexEqual` (`crypto.dart:30`) — **corrected from revision 1's flat "yes".** Functional correctness *is* confirmed by execution, including mismatched-length inputs, and the implementation reads as constant-time (OR-accumulator seeded with the length XOR, no early exit). But **the actual timing side-channel property was never measured** by anyone, this session included. Grade: SOURCE, not EXECUTED. Its only call site (`callback.dart:119`) is already guaranteed two 128-char hex strings.
- The HMAC comparison (`callback_token.dart:156`) traced through `package:hashlib` into `convertlib`'s `constantTimeEquals` (`convertlib-3.6.1/lib/src/constant_time.dart`) — no early exit, folds every byte. **SOURCE**
- `createZpMupid` (`crypto.dart:117`) uses hashlib's default `RNG.secure` CSPRNG, not overridden. **SOURCE**
- **No secret, HMAC key or password reaches a log, an exception message, or a URL query string** anywhere in `lib/src/` — re-verified by grep; there are zero logging call sites in the package at all. **EXECUTED**

**Validation**
- `verifyZpCallback` never lets a raw exception escape: **0 of 16 hostile inputs threw** (missing `response`, non-map `response`, non-string keys, wrong-length/non-hex/null `validationCode`, deeply nested junk, huge strings) — every call returned a typed result. **EXECUTED**
- `verifyZpCallbackUrlToken` maps every malformed-token shape to a typed failure; both `_base64UrlDecode` calls confirmed inside `try`/`on FormatException`. **SOURCE**
- Expiry uses `DateTime.now().toUtc()` consistently on mint and verify — no timezone mismatch. **SOURCE**
- `zpAmountToCents` is regex-gated (`^\d+(?:\.\d{1,2})?$`) before parsing, rejecting negatives, scientific notation and NaN/Infinity string forms. **SOURCE**
- Enum `fromWireValue`/`tryFromWireValue` reject unknown integers per contract. **SOURCE**

**URLs & API surface**
- Query-value percent-encoding: exactly one pass, correct round-trip for `%`, `&`, `#`, unicode, empty string. **EXECUTED**
- Every nullable field omitted (not `key=`) when unset. **SOURCE**
- No internal type (`ZpCore`, `ZpPatterns`, `ZpErrors`, `ZpCheckoutDefaults`, `resolveZpHashAmountChecked`, …) appears in any exported signature; every type in a public signature is itself exported. **SOURCE**

**Packaging** (all **MEASURED** by pana unless noted)
- `[*] 10/10` OSI licence — `Apache-2.0` detected, real file inside the package directory.
- `[*] 5/5` valid README · `[*] 5/5` valid CHANGELOG (top entry `## 0.1.0` matches `pubspec.yaml`).
- `[*] 20/20` platform support — 6 of 6 platforms, WASM-ready. `[*] 40/40` dependencies: all up to date, latest stable Dart/Flutter supported, and `pub downgrade` exposes no error at constraint lower bounds.
- No `path:`, `git:` or unbounded dependency. A `path:` dependency would block publication outright — **DOC**, dart.dev publishing docs.
- `resolution: workspace` is transparently stripped by pana before analysis (`sdk_env.dart:660-661`; CHANGELOG 0.22.10) and does not block publish or affect consumers. **SOURCE + DOC** — both packages were scored with the field left in place.
- `description` 150 chars, inside the documented 60–180 band. (Noted: pana's own code enforces 50 as the low bound in one place while citing 60 in a suggestion string — a docs-vs-code inconsistency, irrelevant at 150.)
- `.pubignore` excludes only `CLAUDE.md`/`AGENTS.md`; nothing sensitive ships, nothing required is excluded.
- `sdk: ^3.13.0` is justified: `lib/src/models/` uses primary-constructor syntax, stable exactly as of Dart 3.13 (2026-08-12).

## TypeScript SDK parity — `F:\_ZP-Main\apps\HPP-TS\src\v6`

Checked because the TS SDK is the source of truth for intended behaviour; a Dart-only gap is a port regression, a shared gap is a design decision.

| Question | Verdict |
|---|---|
| `merchantCode` charset validation | **TS has the same gap** — `generate-url.ts:49-59,132-140`, raw concat, no charset check. Finding #1 stays MEDIUM. |
| Pre-encoded `%2F` passthrough | **Dart matches TS** — both emit it byte-for-byte; verified by running both builders. Not a Dart defect. |
| NaN/Infinity payment amount | **DART DIVERGES — port regression.** TS's Zod schema rejects them (`callbackurl-token.ts:279-284`); Dart lost the guard. Finding #2. |
| Callback hash + signature verification | **Dart matches TS** — identical 7-field hash-pipe order, byte-identical constant-time comparison. Neither language checks expiry inside the callback hash. |
| `apiKey` / `fingerprint` validation | **Partial divergence, unenforced in TS.** TS's real URL path is `isEmpty`-only like Dart, but TS also ships an *optional* Zod schema with a 128-hex-char fingerprint check that `createZpCheckoutUrl` never calls. Dart has no equivalent even as an option. Informational — TS doesn't enforce it either. |

No other divergence cleared the evidence bar. One TS quirk (`generate-url.ts` decoding the whole string) is something `checkout_url.dart`'s own header comment already documents and deliberately avoids — a Dart improvement, not a finding.

## Still open

- **Timing side-channel measurement** of `constantTimeHexEqual` — never measured; would need a statistical timing harness. (Implementation matches TS byte-for-byte, so this is a shared property, not a port issue.)
- **ZenPay's server-side decoding of a raw `%2F`** — needs a live call. Not a Dart-vs-TS difference; both SDKs emit the same string.
- **pana on Windows** — numbers come from 0.23.16 because 0.23.18 cannot run here. A Linux CI run on latest pana would confirm the 150/160 independently.
- TypeScript reference-SDK parity — deliberately out of scope.

## Working tree note

`zenpay_dart/README.md` was modified by something outside this review while it ran (a `scripts/run-backend.ps1` reference replaced with `dart run cli.dart --server`, net-zero lines). Verified afterwards that `zenpay_dart/lib/`, `test/`, `pubspec.yaml`, `analysis_options.yaml` and `CHANGELOG.md` are **untouched**, so every finding stands. Other files outside both reviewed packages (root `README.md`, `cli.dart`, `example/**`, `scripts/**`) also changed in the same window — not by this review, which modified nothing.
