# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2026-08-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`zenpay_flutter` - `v0.1.1`](#zenpay_flutter---v011)

---

#### `zenpay_flutter` - `v0.1.1`

 - **REFACTOR**(core): centralize constants, fix firebase_app_distribution import, and update docs.
 - **FIX**: sync App Link config, harden checkout URL/callback validation, close zenpay_flutter release findings.
 - **FEAT**: implement full ZenPay SDK architecture including core, flutter, embedded, and backend example application scaffolding.
 - **FEAT**: implement core ZenPay Dart SDK architecture with URL/fingerprint builders and callback verification logic.
 - **FEAT**: implement web return popup handling and add repository CLAUDE.md verification tools.
 - **FEAT**: implement secure in-app WebView checkout rendering and return URI interception in zenpay_embedded.
 - **FEAT**: implement checkout URL generation, callback verification, and cryptographic utility modules.
 - **FEAT**: initialize zenpay_dart package and configure .pubignore files for both SDK components.
 - **FEAT**: implement recaptcha and update core models.
 - **FEAT**: add zenpay_embedded optional in-app WebView checkout presentation.
 - **FEAT**: enforce App Check on exchange, optional mode-1 amount, bundle Roboto.
 - **FEAT**(zenpay_flutter): initial Flutter SDK implementation.
 - **DOCS**: add README.md for zenpay_flutter package.
 - **DOCS**: update ZpTimedOut description to 10 minutes and add source documentation across sub-packages.
 - **DOCS**: add CLAUDE.md reference guides for all modules and define transaction enum models.
 - **DOCS**: add CLAUDE.md and AGENTS.md documentation files, and add internal package synchronization script.

