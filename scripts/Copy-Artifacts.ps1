# scripts/Copy-Artifacts.ps1
# Extracts build artifacts from the VM to your host machine.
# Can be run while the VM is running or after shutdown.

param(
    [string]$DestPath   = ".\artifacts",
    [string]$VMBuildPath = "C:\workspace\target\release",

    # Additional glob patterns to copy (beyond .exe/.dll/.pdb)
    [string[]]$ExtraPatterns = @(),

    # If set, waits for the VM to shut down before extracting
    [switch]$WaitForShutdown
)

$cfg      = Get-Content "$env:USERPROFILE\.claude-sandbox\config.json" | ConvertFrom-Json
$cred     = Import-Clixml "$env:USERPROFILE\.claude-sandbox\vm-cred.xml"
$DestPath = Resolve-Path $DestPath -ErrorAction SilentlyContinue ?? $DestPath

# -- Optionally wait for VM shutdown --
if ($WaitForShutdown) {
    Write-Host "Waiting for VM to shut down..."
    while ((Get-VM -Name $cfg.VMName).State -ne "Off") {
        Start-Sleep -Seconds 5
        Write-Host "  Still running..."
    }
    Write-Host "  VM stopped."
}

# -- Connect and extract --
Write-Host "Connecting to VM..."
$session = New-PSSession -VMName $cfg.VMName -Credential $cred

try {
    New-Item -ItemType Directory -Force -Path $DestPath | Out-Null

    $patterns = @("*.exe", "*.dll", "*.pdb") + $ExtraPatterns

    Write-Host "Copying artifacts from VM:$VMBuildPath ..."

    foreach ($pattern in $patterns) {
        $remotePath = "$VMBuildPath\$pattern"
        Copy-Item -FromSession $session `
                  -Path $remotePath `
                  -Destination $DestPath `
                  -ErrorAction SilentlyContinue
    }

    $copied = Get-ChildItem $DestPath
    if ($copied.Count -eq 0) {
        Write-Host "WARNING: No artifacts found at $VMBuildPath"
        Write-Host "         Check that 'cargo build --release' completed successfully."
    } else {
        Write-Host ""
        Write-Host "Artifacts saved to: $DestPath"
        $copied | Format-Table Name, @{L="Size (KB)"; E={[math]::Round($_.Length/1KB, 1)}}, LastWriteTime
    }
} finally {
    Remove-PSSession $session
}
