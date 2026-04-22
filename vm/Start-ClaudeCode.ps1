# vm/Start-ClaudeCode.ps1
# Optional: place this in the VM's startup folder so Claude Code
# launches automatically in the right directory when the VM boots.
# Path inside VM: C:\Users\<user>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\

$workspacePath = "C:\workspace"

# Sync shared project files into workspace on boot
$sharedProject = "\\localhost\ClaudeSandboxShare\project"
if (Test-Path $sharedProject) {
    Write-Host "Syncing project from host share..."
    robocopy $sharedProject $workspacePath /MIR /NFL /NDL /NJH | Out-Null
}

# Launch Windows Terminal with Claude Code
Start-Process "wt" -ArgumentList "powershell -NoExit -Command `"
    Set-Location '$workspacePath'
    Write-Host 'Claude Code Sandbox VM' -ForegroundColor Cyan
    Write-Host 'Project: $workspacePath' -ForegroundColor Gray
    Write-Host ''
    claude
`""
