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

    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<VMSavedConfig>
    <FullScreen>False</FullScreen>
    <DesktopSize>1920, 1080</DesktopSize>
    <UseAllMonitors>False</UseAllMonitors>
    <SavedConfigExists>True</SavedConfigExists>
    <Microsoft.Virtualization.Client.RdpOptions>
        <setting name="AudioCaptureRedirectionMode" type="System.Boolean">
            <value>False</value>
        </setting>
        <setting name="EnablePrinterRedirection" type="System.Boolean">
            <value>True</value>
        </setting>
        <setting name="FullScreen" type="System.Boolean">
            <value>False</value>
        </setting>
        <setting name="SmartCardsRedirection" type="System.Boolean">
            <value>True</value>
        </setting>
        <setting name="RedirectedPnpDevices" type="System.String">
            <value />
        </setting>
        <setting name="ClipboardRedirection" type="System.Boolean">
            <value>True</value>
        </setting>
        <setting name="DesktopSize" type="System.Drawing.Size">
            <value>1920, 1080</value>
        </setting>
        <setting name="VmServerName" type="System.String">
            <value>$env:COMPUTERNAME</value>
        </setting>
        <setting name="RedirectedUsbDevices" type="System.String">
            <value />
        </setting>
        <setting name="SavedConfigExists" type="System.Boolean">
            <value>True</value>
        </setting>
        <setting name="UseAllMonitors" type="System.Boolean">
            <value>False</value>
        </setting>
        <setting name="AudioPlaybackRedirectionMode" type="Microsoft.Virtualization.Client.RdpOptions+AudioPlaybackRedirectionType">
            <value>AUDIO_MODE_REDIRECT</value>
        </setting>
        <setting name="PrinterRedirection" type="System.Boolean">
            <value>True</value>
        </setting>
        <setting name="WebAuthnRedirection" type="System.Boolean">
            <value>True</value>
        </setting>
        <setting name="RedirectedDrives" type="System.String">
            <value />
        </setting>
        <setting name="VmName" type="System.String">
            <value>$VMName</value>
        </setting>
        <setting name="SaveButtonChecked" type="System.Boolean">
            <value>True</value>
        </setting>
    </Microsoft.Virtualization.Client.RdpOptions>
</VMSavedConfig>
"@

    Set-Content -Path $configFile -Value $xml -Encoding UTF8
}

vmconnect.exe localhost $VMName
