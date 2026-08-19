# App Link / Universal Link verification files

Served at `/.well-known/assetlinks.json` and
`/.well-known/apple-app-site-association`. Both are `404` until you create the
real files here — copy each `.example` and fill in the placeholder:

| File | Placeholder | Where it comes from |
|---|---|---|
| `assetlinks.json` | `REPLACE_WITH_SIGNING_CERT_SHA256` | `keytool -list -v -keystore <keystore> -alias <alias>` |
| `apple-app-site-association` | `REPLACE_WITH_TEAM_ID` | Apple Developer account → Membership → Team ID |

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
