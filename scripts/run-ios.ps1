[CmdletBinding()]
param(
    [string]$DeviceId
)

# Requires macOS + Xcode — Flutter cannot build iOS on Windows at all, not even
# against a physical device. This script exists for when the repo is checked
# out on a Mac.
#
# Assumes the backend is already running — scripts/run-backend.ps1. There is no
# adb-reverse equivalent: the simulator shares the host's localhost directly,
# and a physical device needs the backend on the LAN or behind a tunnel (see
# example/backend/.env.example, PUBLIC_BASE_URL).
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Push-Location (Join-Path $Root "example\app")
try {
    if ($DeviceId) {
        flutter run -d $DeviceId --dart-define-from-file=.env
    } else {
        flutter run --dart-define-from-file=.env
    }
} finally {
    Pop-Location
}
