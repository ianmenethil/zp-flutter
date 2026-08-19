[CmdletBinding()]
param()

# Assumes the backend is already running — scripts/run-backend.ps1.
#
# TLS: the SDK requires an https return URI, so APP_RETURN_URI for web points at
# https://localhost:3000. That only works if Flutter serves over TLS, which
# needs a local cert — generate one with `mkcert localhost 127.0.0.1 ::1` in
# example/app. Without the cert files the script still runs, over plain http,
# and the return will be rejected as an address mismatch.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $Root "example\app"

$cert = Join-Path $AppDir "localhost+2.pem"
$key = Join-Path $AppDir "localhost+2-key.pem"

# Deliberately not running `mkcert -install`: that writes a CA into the machine
# trust store, which is not something a run script should do behind your back.
# Without it the cert is generated but untrusted, and Chrome shows a warning.
if (-not ((Test-Path $cert) -and (Test-Path $key))) {
    if (Get-Command mkcert -ErrorAction SilentlyContinue) {
        Write-Host "No TLS cert — running mkcert in example/app." -ForegroundColor Cyan
        Push-Location $AppDir
        try { mkcert localhost 127.0.0.1 ::1 } catch { } finally { Pop-Location }
    }
}

$tls = @()
if ((Test-Path $cert) -and (Test-Path $key)) {
    $tls = @("--web-tls-cert-path", "localhost+2.pem", "--web-tls-cert-key-path", "localhost+2-key.pem")
}
else {
    Write-Host "No TLS cert — serving http. The https return URI will not match. Install mkcert (choco install mkcert), run 'mkcert -install' once, then re-run this script." -ForegroundColor Yellow
}

Push-Location $AppDir
try {
    # Do not add --web-browser-flag=--window-size=W,H here. flutter registers
    # --web-browser-flag as an addMultiOption and package:args splits its value
    # on every comma (parser.dart:342, no escape), so the height arrives as a
    # separate argument that Chrome resolves as a 32-bit IP and opens in a junk
    # tab. For a phone viewport use Chrome's device toolbar: F12, Ctrl+Shift+M.
    # --auto-open-devtools-for-tabs has no comma, so it survives that split.
    flutter run -d chrome `
        --web-hostname localhost `
        --web-port 3000 `
        --web-browser-flag="--auto-open-devtools-for-tabs" `
        @tls `
        --dart-define-from-file=.env
}
finally {
    Pop-Location
}
