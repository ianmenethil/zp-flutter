[CmdletBinding()]
param(
    # Skip the prompt and use this value.
    [string]$PublicBaseUrl,
    # Skip the prompt entirely and leave .env as-is.
    [switch]$KeepUrl
)

# Starts the example backend on the port in example/backend/.env (default 7000).
# Every other run-*.ps1 assumes this is already running.
#
# Prompts for PUBLIC_BASE_URL first, because it changes every time a tunnel is
# restarted and a stale value fails in two ways that are hard to spot: ZenPay
# posts callbacks to the dead URL, and the mobile return URI stops matching.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $Root "example\backend"
$EnvFile = Join-Path $BackendDir ".env"

if (-not (Test-Path $EnvFile)) {
    throw "No .env at $EnvFile — copy .env.example to .env and fill in your ZenPay credentials."
}

if (-not $KeepUrl) {
    $content = Get-Content $EnvFile -Raw
    $current = if ($content -match '(?m)^PUBLIC_BASE_URL\s*=\s*(.*)$') { $matches[1].Trim() } else { "(not set)" }

    if (-not $PublicBaseUrl) {
        Write-Host "Current PUBLIC_BASE_URL: $current" -ForegroundColor Green
        Write-Host "For live callbacks or mobile deep links this must be a public HTTPS host:" -ForegroundColor DarkGray
        Write-Host "  cloudflared tunnel --url http://localhost:7000" -ForegroundColor DarkGray
        $PublicBaseUrl = (Read-Host "New PUBLIC_BASE_URL (Enter to keep)").Trim()
    }

    if ($PublicBaseUrl) {
        $content = $content -replace '(?m)^PUBLIC_BASE_URL\s*=.*$', "PUBLIC_BASE_URL=$PublicBaseUrl"
        Set-Content -Path $EnvFile -Value $content -NoNewline
        Write-Host "PUBLIC_BASE_URL set to $PublicBaseUrl" -ForegroundColor Cyan

        # Three other places derive from this host. Leaving any of them stale
        # fails silently — the SDK compares the return URI exactly, and App Link
        # verification compares the host — so update them here rather than
        # printing instructions and hoping.
        $uri = [System.Uri]$PublicBaseUrl
        $mobileReturn = "$($PublicBaseUrl.TrimEnd('/'))/zenpay/app-return"

        $appEnv = Join-Path $Root "example\app\.env"
        if (Test-Path $appEnv) {
            $appContent = Get-Content $appEnv -Raw
            $appContent = $appContent -replace '(?m)^APP_RETURN_URI_MOBILE\s*=.*$', "APP_RETURN_URI_MOBILE=$mobileReturn"
            Set-Content -Path $appEnv -Value $appContent -NoNewline
            Write-Host "APP_RETURN_URI_MOBILE -> $mobileReturn" -ForegroundColor Cyan
        } else {
            Write-Host "No example/app/.env — copy .env.example, then re-run." -ForegroundColor Yellow
        }

        if (Test-Path (Join-Path $Root "example\app\android")) {
            Push-Location $Root
            try {
                dart run scripts/apply_platform_config.dart --host $uri.Host
            } finally {
                Pop-Location
            }
        }
    }
}

Push-Location $BackendDir
try {
    dart run bin/server.dart
} finally {
    Pop-Location
}
