# ZenPay Hosted Checkout SDK for Flutter

Monorepo for the ZenPay Hosted Checkout Plugin (HCP) Dart/Flutter ecosystem: a pure-Dart backend SDK, a Flutter client SDK, and a runnable example that wires both together end-to-end.

🌐 **Live Web Demo:** [flutter-demo.zenithpayments.support](https://flutter-demo.zenithpayments.support)

📖 **New to this repo?** Start with [GETTING_STARTED.md](GETTING_STARTED.md) — clone, bootstrap, run the server and app.

Contributor/agent guidelines: [CLAUDE.md](CLAUDE.md) — start there before touching any package. `AGENTS.md` in this folder is a symlink to it.

---

## 📱 Previews

|     Android Native Launch     |            Android In-App WebView             |
| :---------------------------: | :-------------------------------------------: |
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

| Package                                      | Path              | What it is                                                                                                               |
| :-------------------------------------------- | :---------------- | :----------------------------------------------------------------------------------------------------------------------- |
| [`zenpay_dart`](zenpay_dart/README.md)       | `zenpay_dart/`    | Pure-Dart backend SDK: fingerprints, launch URLs, callback verification, callback URL tokens. Server-side only.          |
| [`zenpay_flutter`](zenpay_flutter/README.md) | `zenpay_flutter/` | Flutter client SDK: presents ZenPay Hosted Checkout, handles the return, reports one typed outcome.                      |
| [example](example/README.md)                 | `example/`        | Combined reference: a Shelf backend (`example/backend/`) and a Flutter app (`example/app/`) demonstrating the full flow. |

Each package has its own `CLAUDE.md` (agent guidelines) and `README.md` (usage docs); every `CLAUDE.md` has an `AGENTS.md` symlink alongside it.

📦 **Third-party dependencies:** See [PACKAGES.md](PACKAGES.md) for every external package this repo uses — version, maintainer, and why.

For setup steps, running the stack, and verifying changes, see [GETTING_STARTED.md](GETTING_STARTED.md).

---

## License

See [LICENSE](LICENSE).
