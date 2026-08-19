# ZenPay Dart Backend Agent Guidelines

Guidelines and standards for working within `zenpay_dart` (pure Dart SDK). This package is responsible for all server-side logic, API models, and cryptography.

---

## 🔗 Related Guides

- **[Monorepo Root](file:///G:/_zp-repos/zp-flutter-sdk/CLAUDE.md)** — General Melos and workspace guidelines, MUPID rule.
- **[Flutter Client SDK](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_flutter/CLAUDE.md)** — UI and client-side orchestration.
- **[Integration Examples](file:///G:/_zp-repos/zp-flutter-sdk/example/CLAUDE.md)** — Reference merchant backend and app that consume this package.
- **[lib/CLAUDE.md](lib/CLAUDE.md)** — Per-file source architecture guide (callback verifiers, tokens, URL builders, crypto, enums).
- **[README.md](README.md)** — Package overview, quick start, API reference.

`AGENTS.md` in this folder is a symlink to this file — edit `CLAUDE.md`, not `AGENTS.md`.

---

## 1. Non-Negotiable Security & Cryptographic Rules

1. **Timing-Safe Equality**:
   - All cryptographic hash (SHA3-512 `ValidationCode`), HMAC-SHA3-512 callback tokens, and bearer token comparisons **must** use timing-safe comparison methods (`constantTimeHexEqual`, `constantTimeEqual`, or constant-time digest comparison) to prevent timing attacks.
2. **Credential & Secret Protection**:
   - Never hardcode ZenPay API keys, merchant passwords, shared secrets, or live credentials.
   - Do not log sensitive fields (passwords, cardholder numbers, CVV, authentication secrets).
   - Safe to log for debugging: `merchantUniquePaymentId`, merchant codes, checkout launch URLs (without raw secrets), customer reference IDs, and callback event types.
3. **Launch URL Generation**:
   - Launch URLs must be constructed locally using query parameter serialization without making outbound network requests at launch time.
4. **Callback & State Verification**:
   - Only validated callback payloads or authenticated direct ZenPay REST status checks can confirm payment completion. Client redirects or browser dismissals are strictly provisional.

---

## 2. Dart Strictness & Code Quality

Adhere strictly to [analysis_options.yaml](file:///G:/_zp-repos/zp-flutter-sdk/zenpay_dart/analysis_options.yaml):

1. **Strict Type Safety**:
   - `strict-casts: true`, `strict-inference: true`, `strict-raw-types: true`.
   - Never use untyped `dynamic` or `avoid_dynamic_calls`. Use explicit generics and model types.
2. **Public API Documentation**:
   - `public_member_api_docs: error` is enforced on the core package. Every exported class, method, enum, getter, and typedef in `lib/` must have a comprehensive doc comment explaining its parameters, return values, and failure modes.
3. **Dead Code & Unused Elements**:
   - Unused private members, unused imports, and unused local variables are compiler errors (`error`). Clean them up immediately rather than adding suppression comments.
4. **Style**:
   - Always prefer `final` locals.
   - Sort constructors first.
   - Follow standard `dart format` (80-character line width default).

---

## 3. Verification Commands

This package is part of a Melos monorepo. Before completing any change, ensure all checks pass by running the following from the **repository root**:

```pwsh
melos run format
melos run analyze
melos run lint
melos run test
```
