# zp-flutter-sdk

Monorepo for the ZenPay Hosted Checkout Plugin (HCP) Dart/Flutter ecosystem: a
pure-Dart backend SDK, a Flutter client SDK, and a runnable example that wires
both together end to end.

Contributor/agent guidelines: [CLAUDE.md](CLAUDE.md) — start there before
touching any package. `AGENTS.md` in this folder is a symlink to it.

---

## Packages

| Package                                     | Path               | What it is                                                                 |
| :------------------------------------------- | :------------------ | :--------------------------------------------------------------------------- |
| [`zenpay_dart`](zenpay_dart/README.md)       | `zenpay_dart/`      | Pure-Dart backend SDK: fingerprints, launch URLs, callback verification, callback URL tokens. Server-side only. |
| [`zenpay_flutter`](zenpay_flutter/README.md) | `zenpay_flutter/`   | Flutter client SDK: presents ZenPay Hosted Checkout, handles the return, reports one typed outcome. |
| [example](example/README.md)                 | `example/`          | Combined reference: a Shelf backend (`example/backend/`) and a Flutter app (`example/app/`) demonstrating the full flow. |

Each package has its own `CLAUDE.md` (agent guidelines) and `README.md`
(usage docs); every `CLAUDE.md` has an `AGENTS.md` symlink alongside it.

---

## Quick Start

This is a [Dart pub workspace](https://dart.dev/tools/pub/workspaces) managed
with [Melos](https://melos.invertase.dev). See root
[`pubspec.yaml`](pubspec.yaml) for the workspace member list and Melos script
definitions.

```pwsh
melos bs              # bootstrap — links local path: deps across all packages
melos run format
melos run analyze
melos run lint
melos run test
```

**Never** run `flutter pub get` or `dart pub get` manually in a subdirectory —
always bootstrap from the root with `melos bs`.

To actually run the example app and backend (not just verify the code), see
[scripts/README.md](scripts/README.md):

```pwsh
./scripts/bootstrap.ps1       # once per machine — TLS cert for web checkout
./scripts/run-backend.ps1     # example/backend on :7000
./scripts/run-android.ps1     # or run-ios.ps1 / run-web.ps1
```

---

## Design Rule

`merchantUniquePaymentId` (MUPID) is an ordinary opaque identifier, not a
correlation mechanism the SDK verifies or matches — see
[CLAUDE.md § MUPID](CLAUDE.md) before adding anything that treats it
specially.

---

## License

See [LICENSE](LICENSE).
