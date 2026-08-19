[CmdletBinding()]
param(
    # Skip the local TLS cert step (web checkout will not be testable).
    [switch]$SkipCerts
)

# First-run setup for a fresh clone: resolve the pub workspace and create the
# local files that are deliberately not committed.
#
# It does NOT regenerate example/app/android or ios. Those are committed, per
# Flutter's own .gitignore template, and hold hand-edited configuration —
# manifest intent-filter, entitlements, signing, bundle ids — that regenerating
# would destroy. To change the App Link host, use apply_platform_config.dart.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

foreach ($command in @("flutter", "dart")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $command"
    }
}

# One resolve covers every package: melos 7+ delegates linking to Dart pub
# workspaces, so the root pubspec's `workspace:` list is what fans this out.
Write-Host "Resolving pub workspace..." -ForegroundColor Cyan
Push-Location $Root
try {
    dart pub get
} finally {
    Pop-Location
}

# .env files are gitignored, so a fresh clone has none and the backend now
# refuses to start without one.
foreach ($pkg in @("example\backend", "example\app")) {
    $envFile = Join-Path $Root "$pkg\.env"
    $template = "$envFile.example"
    if ((Test-Path $template) -and -not (Test-Path $envFile)) {
        Copy-Item $template $envFile
        Write-Host "Created $pkg\.env from template" -ForegroundColor Cyan
    }
}

# The SDK rejects any non-https return URI, so the web flow needs TLS even on
# localhost. Mobile does not — its return is an App Link on the public host.
if (-not $SkipCerts) {
    $appDir = Join-Path $Root "example\app"
    if (Test-Path (Join-Path $appDir "localhost+2.pem")) {
        Write-Host "TLS cert already present." -ForegroundColor DarkGray
    } elseif (Get-Command mkcert -ErrorAction SilentlyContinue) {
        Push-Location $appDir
        try {
            mkcert -install
            mkcert localhost 127.0.0.1 ::1
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "mkcert not installed — skipping TLS cert. Web checkout returns will not match until you install it and re-run." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Bootstrap complete. Next:" -ForegroundColor Green
Write-Host "  1. Fill in ZENPAY_* credentials in example/backend/.env — the server will not start without them."
Write-Host "  2. ./scripts/run-backend.ps1   (prompts for PUBLIC_BASE_URL and propagates it)"
Write-Host "  3. ./scripts/run-android.ps1 | run-ios.ps1 | run-web.ps1"
