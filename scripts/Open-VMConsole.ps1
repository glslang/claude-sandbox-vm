# scripts/Open-VMConsole.ps1
# Wrapper around vmconnect.exe that pre-populates the per-VM saved-config XML
# so Hyper-V skips its "Display configuration" dialog on first launch.
#
# vmconnect persists settings at:
#   %APPDATA%\Microsoft\Windows\Hyper-V\Client\1.0\vmconnect.rdp.<VMGUID>.config
# and skips the dialog when that file exists with <SavedConfigExists>True</SavedConfigExists>.
#
# Idempotent: only writes the file if it does not already exist, so a user's
# manual "Save my settings" choice in the dialog is preserved.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VMName
)

$ErrorActionPreference = "Stop"

$vmGuid = (Get-VM -Name $VMName).Id.Guid
$configDir = Join-Path $env:APPDATA "Microsoft\Windows\Hyper-V\Client\1.0"
$configFile = Join-Path $configDir "vmconnect.rdp.$vmGuid.config"

if (-not (Test-Path $configFile)) {
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null

    $xml = @'
<?xml version="1.0" encoding="utf-8"?>
<VMSavedConfig>
  <FullScreen>False</FullScreen>
  <DesktopSize>1920, 1080</DesktopSize>
  <UseAllMonitors>False</UseAllMonitors>
  <SavedConfigExists>True</SavedConfigExists>
</VMSavedConfig>
'@

    Set-Content -Path $configFile -Value $xml -Encoding UTF8
}

vmconnect.exe localhost $VMName
