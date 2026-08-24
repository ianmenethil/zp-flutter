# ZenPay Hosted Checkout SDK for Flutter

Monorepo for the ZenPay Hosted Checkout Plugin (HCP) Dart/Flutter ecosystem: a pure-Dart backend SDK, a Flutter client SDK, and a runnable example that wires both together end-to-end.

🌐 **Live Web Demo:** [flutter-demo.zenithpayments.support](https://flutter-demo.zenithpayments.support)

Contributor/agent guidelines: [CLAUDE.md](CLAUDE.md) — start there before touching any package. `AGENTS.md` in this folder is a symlink to it.

---

## 📱 Previews

| Android Native Launch | Android In-App WebView |
| :---: | :---: |
| ![Android Demo](android.webp) | ![Android WebView Demo](android-webview.webp) |

---

## 🏗️ Architecture & Flow

The repository is structured to mirror exactly how you will integrate ZenPay into your own production systems. The client app uses the Flutter SDK for presentation, while a backend server uses the pure-Dart SDK to handle cryptography and secure session creation.

```mermaid
graph TD
    subgraph example ["Integration Example"]
        APP[example/app<br/>(Flutter Mobile/Web)]
        BACKEND[example/backend<br/>(Shelf Server)]
    end
    
    subgraph sdks ["ZenPay SDKs"]
        F_SDK[zenpay_flutter<br/>(Client SDK)]
        D_SDK[zenpay_dart<br/>(Backend SDK)]
    end
    
    APP -->|Uses| F_SDK
    BACKEND -->|Uses| D_SDK
    
    APP -->|1. Request Checkout Token| BACKEND
    BACKEND -->|2. Generate Hash & URL| D_SDK
    BACKEND -.->|3. Return Token| APP
    APP -->|4. Present Checkout| F_SDK
    F_SDK -.->|5. Deep-link Return| APP
    APP -->|6. Verify Status| BACKEND
```

---

## 📦 Packages

| Package                                     | Path               | What it is                                                                 |
| :------------------------------------------- | :------------------ | :--------------------------------------------------------------------------- |
| [`zenpay_dart`](zenpay_dart/README.md)       | `zenpay_dart/`      | Pure-Dart backend SDK: fingerprints, launch URLs, callback verification, callback URL tokens. Server-side only. |
| [`zenpay_flutter`](zenpay_flutter/README.md) | `zenpay_flutter/`   | Flutter client SDK: presents ZenPay Hosted Checkout, handles the return, reports one typed outcome. |
| [example](example/README.md)                 | `example/`          | Combined reference: a Shelf backend (`example/backend/`) and a Flutter app (`example/app/`) demonstrating the full flow. |

Each package has its own `CLAUDE.md` (agent guidelines) and `README.md` (usage docs); every `CLAUDE.md` has an `AGENTS.md` symlink alongside it.

---

## 🚀 Getting Started

Requires the Flutter SDK and Dart SDK on `PATH` (`mkcert` too, if you want the
local TLS cert for web checkout). Run these **in order**:

1. Clone this repo.
2. ```pwsh
   dart run cli.dart --bootstrap
   ```
   Resolves the pub workspace, creates `example/backend/.env` and
   `example/app/.env` from their templates, and sets up the local TLS cert
   for web checkout.
3. Fill in your `ZENPAY_*` credentials in `example/backend/.env` — the
   server will not start without them.
4. ```pwsh
   dart run cli.dart --server
   ```
   Starts `example/backend` on `:7000`. Prompts for `PUBLIC_BASE_URL` and
   propagates it to `example/app/.env` and the native Android/iOS App Link
   config.
5. ```pwsh
   dart run cli.dart --android   # or --ios / --web
   ```
   Starts `example/app`, talking to the backend from step 4.

`dart run cli.dart --help` lists every other mode (named/quick tunnels,
Docker, Cloudflare deploy, release bumps). See
[example/README.md](example/README.md) for local dev vs. production hosts.

### Verifying changes

This is a [Dart pub workspace](https://dart.dev/tools/pub/workspaces)
managed with [Melos](https://melos.invertase.dev) — see root
[`pubspec.yaml`](pubspec.yaml) for the workspace member list and Melos
script definitions. Run from the repo root, independent of the steps above:

```pwsh
melos bs              # links local path: deps across all packages
melos run format
melos run analyze
melos run lint
melos run test
```

**Never** run `flutter pub get` or `dart pub get` manually in a subdirectory — always bootstrap from the root with `melos bs`.

---

## License

See [LICENSE](LICENSE).
