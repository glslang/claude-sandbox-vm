# scripts/Invoke-Provision.ps1
# Run INSIDE the VM as Administrator after Windows is installed.
# Installs VS Build Tools, Rust, Node, Claude Code, and enables PSRemoting.
#
# Expects:
#   - Internet access (Default Switch must be active)
#   - VS Build Tools layout at C:\vs-cache\layout (copied in by Start-Provision.ps1)
#     OR falls back to downloading from internet

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "----------------------------------------------"
Write-Host "  Claude Code Sandbox VM -- Provisioning"
Write-Host "----------------------------------------------"
Write-Host ""

# -- Helper --
function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

# -- 1. VS Build Tools --
Write-Host "[1/7] Installing VS Build Tools..."

$layoutInstaller = "C:\vs-cache\layout\vs_buildtools.exe"
$onlineInstaller = "$env:TEMP\vs_buildtools.exe"

if (Test-Path $layoutInstaller) {
    Write-Host "  Using offline layout (fast)..."
    $installer = $layoutInstaller
    $extraArgs = @("--noweb")
} else {
    Write-Host "  Offline layout not found -- downloading from internet..."
    Invoke-WebRequest "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile $onlineInstaller
    $installer = $onlineInstaller
    $extraArgs = @()
}

$proc = Start-Process $installer -ArgumentList (@(
    "--add", "Microsoft.VisualStudio.Workload.VCTools",
    "--add", "Microsoft.VisualStudio.Component.Windows11SDK.26100",
    "--add", "Microsoft.VisualStudio.Component.VC.CMake.Project",
    "--includeRecommended",
    "--quiet", "--wait", "--norestart"
) + $extraArgs) -Wait -NoNewWindow -PassThru

if ($proc.ExitCode -notin 0, 3010) {
    Write-Warning "  VS Build Tools exited with code $($proc.ExitCode)"
} else {
    Write-Host "  VS Build Tools installed."
}

# -- 2. Rust (MSVC toolchain) --
Write-Host "[2/7] Installing Rust..."

Invoke-WebRequest "https://win.rustup.rs/x86_64" -OutFile "$env:TEMP\rustup-init.exe"
& "$env:TEMP\rustup-init.exe" -y --default-toolchain stable --default-host x86_64-pc-windows-msvc
Refresh-Path
rustup component add clippy rustfmt
Write-Host "  Rust installed: $(rustc --version)"

# -- 3. Node.js --
Write-Host "[3/7] Installing Node.js..."

winget install --silent --accept-package-agreements --accept-source-agreements OpenJS.NodeJS
Refresh-Path
Write-Host "  Node installed: $(node --version)"

# -- 4. Git for Windows (Git Bash) --
Write-Host "[4/7] Installing Git for Windows..."

winget install --silent --accept-package-agreements --accept-source-agreements Git.Git
Refresh-Path

# Locate bash.exe and pin it via CLAUDE_CODE_GIT_BASH_PATH so Claude Code can
# find it even when Git's bin dir is not first on PATH.
$gitBashCandidates = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe"
)
$gitBashExe = $gitBashCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($gitBashExe) {
    [System.Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $gitBashExe, "Machine")
    $env:CLAUDE_CODE_GIT_BASH_PATH = $gitBashExe
    Write-Host "  Git Bash installed: $gitBashExe"
    Write-Host "  Set CLAUDE_CODE_GIT_BASH_PATH=$gitBashExe"
} else {
    Write-Warning "  bash.exe not found in expected locations -- set CLAUDE_CODE_GIT_BASH_PATH manually."
}

# -- 5. Claude Code --
Write-Host "[5/7] Installing Claude Code..."

npm install -g @anthropic-ai/claude-code
Refresh-Path
Write-Host "  Claude Code installed: $(claude --version)"

# -- 6. Authenticate --
Write-Host "[6/7] Authenticating with Claude..."
Write-Host "      A browser window will open. Complete the OAuth flow."
Write-Host ""
claude login
Write-Host "  Authentication complete."

# -- 7. Enable PSRemoting (for artifact extraction from host) --
Write-Host "[7/7] Enabling PowerShell remoting..."

Enable-PSRemoting -Force -SkipNetworkProfileCheck
Set-Service WinRM -StartupType Automatic
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Create workspace directory
New-Item -ItemType Directory -Force -Path "C:\workspace" | Out-Null

Write-Host ""
Write-Host "----------------------------------------------"
Write-Host "  Provisioning complete!"
Write-Host ""
Write-Host "  Shut down this VM now, then on your HOST:"
Write-Host "    .\scripts\Save-BaseSnapshot.ps1"
Write-Host "----------------------------------------------"
