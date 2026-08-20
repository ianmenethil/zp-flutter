# App Link / Universal Link verification files

Served at `/.well-known/assetlinks.json` and
`/.well-known/apple-app-site-association`. Both files live directly in this
directory (`_handleWellKnown` in `../lib/src/server_app.dart` 404s if either
is missing) and must have their placeholder filled in with a real value
before the corresponding platform can verify this domain:

| File | Placeholder | Where it comes from | Current state |
|---|---|---|---|
| `assetlinks.json` | `REPLACE_WITH_SIGNING_CERT_SHA256` | `keytool -list -v -keystore <keystore> -alias <alias>` | Filled in with a real-looking cert SHA-256. |
| `apple-app-site-association` | `REPLACE_WITH_TEAM_ID` | Apple Developer account → Membership → Team ID | **Still the literal placeholder** — `appIDs` reads `REPLACE_WITH_TEAM_ID.au.com.zenithpayments.zenpayExampleApp`. Universal Links verification will fail on iOS until a real Team ID replaces it. |

Three things must name the same host, or verification fails silently and the OS
opens a browser instead of the app:

- `android:host` in `app/android/app/src/main/AndroidManifest.xml`
- `applinks:` in `app/ios/Runner/Runner.entitlements`
- `PUBLIC_BASE_URL` in `backend/.env` — this backend serves the files, so its
  public host *is* the return host

The host must be publicly reachable over HTTPS: the OS fetches these files from
the internet at install time, so `localhost` can never verify. Use a tunnel
(`cloudflared tunnel --url http://localhost:7000`) and set `PUBLIC_BASE_URL` to
the HTTPS URL it prints.

Note: `apple-app-site-association` has no `.json` extension by design, and must
be served as `application/json` — both are what Apple's fetcher expects.
