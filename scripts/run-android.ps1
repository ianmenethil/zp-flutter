[CmdletBinding()]
param(
    [string]$DeviceId
)

# Assumes the backend is already running — scripts/run-backend.ps1.
#
# `adb reverse` is what lets the device reach the backend on the host's
# localhost. It is passed -s explicitly because a bare `adb reverse` fails with
# "more than one device/emulator" whenever one phone is connected by USB and
# wirelessly at once, which adb reports as two targets for the same device.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

if (-not $DeviceId) {
    # @(...) forces array semantics even for a single match — without it
    # PowerShell collapses one match to a bare string, and $x[0] then indexes
    # its first *character* rather than the item.
    $devices = @((adb devices) -split "`n" |
        Where-Object { $_ -match "^(\S+)\s+device$" } |
        ForEach-Object { $matches[1] })

    if ($devices.Count -eq 0) {
        throw "No adb devices found. Connect a device or start an emulator."
    } elseif ($devices.Count -eq 1) {
        $DeviceId = $devices[0]
    } else {
        # Same phone over USB and wireless shows up twice — prefer the plain
        # USB serial (no "adb-" mDNS prefix).
        $usb = @($devices | Where-Object { $_ -notmatch "^adb-" })
        if ($usb.Count -eq 1) {
            $DeviceId = $usb[0]
            Write-Host "Multiple adb targets; using USB device $DeviceId (pass -DeviceId to override)." -ForegroundColor Yellow
        } else {
            Write-Host "Multiple devices found:" -ForegroundColor Yellow
            $devices | ForEach-Object { Write-Host "  $_" }
            throw "Ambiguous — re-run with -DeviceId <id>."
        }
    }
}

Write-Host "Using device: $DeviceId" -ForegroundColor Cyan
adb -s $DeviceId reverse tcp:7000 tcp:7000

Push-Location (Join-Path $Root "example\app")
try {
    flutter run -d $DeviceId --dart-define-from-file=.env
} finally {
    Pop-Location
}
