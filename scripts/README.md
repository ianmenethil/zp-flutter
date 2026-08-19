# scripts

`../cli.dart` (repo root) is the dev launcher — one cross-platform Dart file
instead of separate `.ps1`/`.sh` scripts per OS. On a fresh clone run
`--bootstrap` once — it installs the local TLS cert web checkout needs (see
[TLS for web](#tls-for-web)).

Then run the backend; every app mode assumes it is already up.

```powershell
dart run cli.dart --bootstrap   # first-run setup (once)
dart run cli.dart --server      # example/backend on :7000
dart run cli.dart --android     # picks the adb device, sets up adb reverse
dart run cli.dart --ios         # macOS + Xcode only
dart run cli.dart --web         # Chrome at https://localhost:3000
dart run cli.dart --stream      # mirrors a connected Android device via scrcpy
dart run cli.dart --tunnel        # named cloudflared tunnel (saved token)
dart run cli.dart --quick-tunnel  # ephemeral *.trycloudflare.com tunnel
```

Run with `--help` for the full option list (`--device`, `--public-base-url`,
`--keep-url`, `--skip-certs`) — output is colored automatically when the
terminal supports it (`Stdout.supportsAnsiEscapes`), plain text otherwise (e.g.
when redirected to a file). Every mode's app/server process is attached to the
launching terminal — Ctrl+C stops it, nothing runs in the background.

Android and iOS are the primary targets; web is secondary.

`--stream` needs [scrcpy](https://github.com/Genymobile/scrcpy/releases) on
`PATH`; if it's missing the command says so and points at that link rather than
failing silently. It auto-picks the connected device the same way `--android`
does (`--device` overrides).

`--tunnel` and `--quick-tunnel` both need
[cloudflared](https://github.com/cloudflare/cloudflared/releases) on `PATH`,
same missing-tool message pattern as `--stream`. They cover the two different
`cloudflared` tunnel modes:

- **`--tunnel`** runs `cloudflared tunnel run --token <token>` — a named
  tunnel already set up in the Cloudflare dashboard, with a stable URL. The
  token is a durable credential, so it's persisted in
  `example/backend/.env` as `CLOUDFLARE_TUNNEL_TOKEN`, same
  check-current-value → Enter-to-keep-or-paste-new → save flow as `--server`'s
  `PUBLIC_BASE_URL` prompt.
- **`--quick-tunnel`** runs `cloudflared tunnel --url <url>` — no account
  setup, prints a random `https://*.trycloudflare.com` URL each time, gone
  when the process exits. `<url>` is the *local* address being exposed:
  `--url` overrides it, otherwise it's built from `PORT` in
  `example/backend/.env` (falling back to `:7000`). The printed
  `trycloudflare.com` URL is what you then paste into `--server
  --public-base-url=<url>`.

The original `run-*.ps1` / `bootstrap.ps1` files in this folder still work and
do the same thing — `cli.dart` supersedes them but they haven't been deleted.

## TLS for web

Web checkout does not work over plain http. The SDK requires an `https` return
URI — `ZpCheckoutConfiguration` throws otherwise — and on web that URI is the
app's own origin, so the app has to actually be served at
`https://localhost:3000` or the return is rejected as an address mismatch.

That needs a locally trusted cert, which cannot be committed (it is per-machine,
and `localhost+2-key.pem` is a private key). Generate it in `example/app`:

```powershell
choco install mkcert          # or: winget install FiloSottile.mkcert
mkcert -install               # once per machine — adds a local CA
mkcert localhost 127.0.0.1 ::1
```

`--bootstrap` does all three, and `--skip-certs` opts out of that step (bootstrap
without the web cert — `--web` checkout returns won't match until you generate
it later). `--web` retries the last step alone if the cert files are missing,
but never `mkcert -install` — a run command should not write to the machine
trust store on its own. Without the cert `--web` still starts, over http, and
prints a warning; checkout will launch and then fail on the way back.

Mobile is unaffected: it returns to the public host in `APP_RETURN_URI_MOBILE`,
whose cert comes from the tunnel.

## apply_platform_config.dart

```powershell
dart run scripts/apply_platform_config.dart --host payments.yourmerchant.com
```

Writes the App Link / Universal Link config into the generated platform
projects: the `autoVerify` intent-filter and `flutter_deeplinking_enabled=false`
in `AndroidManifest.xml`, `Runner.entitlements` plus `FlutterDeepLinkingEnabled`
and the `CODE_SIGN_ENTITLEMENTS` build setting on iOS.

Run it whenever the return host changes, and after any `flutter create` that
regenerates `android/` or `ios/`. It is idempotent, and it exists so the host is
never hardcoded in a committed manifest.

## Config

All scripts read one file, `example/app/.env` — copy `.env.example` to it
first. It holds both return URIs and the app picks by platform, mirroring the
backend:

| Key | Used on | Example |
|---|---|---|
| `APP_RETURN_URI_WEB` | web | `https://localhost:3000/` |
| `APP_RETURN_URI_MOBILE` | Android, iOS | `https://<host>/zenpay/app-return` |

Values must agree with
`example/backend/.env` — a mismatch in scheme, host, port or path is rejected as
an address mismatch rather than silently ignored.

## Before mobile deep links actually verify

Wiring is done; verification needs three values that cannot live in the repo:

1. **A real host** — replace `payments.example.com` via `apply_platform_config.dart`
2. **Signing cert SHA-256** — `keytool -list -v -keystore <keystore> -alias <alias>` → `example/backend/well_known/assetlinks.json`
3. **Apple Team ID** — developer.apple.com → Membership → `apple-app-site-association`

Plus a public HTTPS host: Android and iOS fetch the `/.well-known/` files from
the internet at install time, so `localhost` can never verify. Use
`cloudflared tunnel --url http://localhost:7000` and set `PUBLIC_BASE_URL` in
`example/backend/.env` to the URL it prints.

## Not ported from `development/scripts`

The melos preflight (`dart run melos run analyze/format/deps:check`) that each
old script ran first. Root `pubspec.yaml` does define a Melos workspace and
`analyze`/`format`/`lint`/`test` scripts now (see [../CLAUDE.md](../CLAUDE.md)),
but `cli.dart` still doesn't call them — running the app and checking the code
are separate jobs, and a launch command that fails on a lint warning is a worse
debugging experience than one that just launches.

## Related Guides

- **[../CLAUDE.md](../CLAUDE.md)** — Monorepo root guidelines and Melos commands.
- **[../example/CLAUDE.md](../example/CLAUDE.md)** — What `--server` and `--android`/`--ios`/`--web` actually start.
