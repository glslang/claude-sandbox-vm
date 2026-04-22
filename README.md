# Claude Code Sandbox VM

A fully scripted Hyper-V sandbox for running [Claude Code](https://code.claude.com) on Windows with native MSVC toolchain support. Claude Code runs inside an isolated VM, builds real Windows binaries, and artifacts are automatically extracted back to your host.

## Requirements

- Windows 10/11 **Pro or Enterprise** (Hyper-V required)
- A Windows 11 ISO ([Media Creation Tool](https://www.microsoft.com/software-download/windows11))
- A [Claude Pro subscription](https://claude.ai) (no API key needed)
- ~15 GB free disk space
- Run everything as **Administrator**

---

## Setup (one-time)

### Step 1 -- Bootstrap

```powershell
.\Bootstrap.ps1
```

This creates the VM, partitions the VHDX, and applies Windows directly via DISM (no DVD boot). Optionally provide an `autounattend.xml` from [schneegans.de](https://schneegans.de/windows/unattend-generator/) to skip OOBE.

### Step 2 -- Complete Windows OOBE

If you didn't provide `autounattend.xml`, complete the setup prompts in the VM console.

### Step 3 -- Provision the VM

```powershell
.\scripts\Start-Provision.ps1
```

This runs **on your host** and:
- Switches the VM to Default Switch (internet access)
- Copies VS Build Tools offline layout + provision script into the VM
- Opens the VM console

Then **inside the VM**, run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Invoke-Provision.ps1
```

This installs VS Build Tools, Rust (MSVC), Node.js, Claude Code, and does OAuth login.

### Step 4 -- Snapshot

After provisioning completes, **shut down the VM**, then on the host:

```powershell
.\scripts\Save-BaseSnapshot.ps1
```

---

## Daily usage

### Start a session

```powershell
# Basic session (no internet in VM -- full isolation)
.\Start-Session.ps1 -ProjectPath C:\Projects\myapp

# With internet (for cargo fetch, npm install, etc.)
.\Start-Session.ps1 -ProjectPath C:\Projects\myapp -Internet

# Clean session from snapshot
.\Start-Session.ps1 -ProjectPath C:\Projects\myapp -Restore -Internet

# Auto-extract artifacts when VM shuts down
.\Start-Session.ps1 -ProjectPath C:\Projects\myapp -Internet -ExtractOnExit
```

Your project is copied to `C:\workspace` inside the VM. Then:

```powershell
cd C:\workspace
claude
```

### Extract artifacts

```powershell
.\scripts\Copy-Artifacts.ps1 -DestPath C:\Projects\myapp\artifacts
.\scripts\Copy-Artifacts.ps1 -WaitForShutdown
.\scripts\Copy-Artifacts.ps1 -ExtraPatterns "*.json","*.toml"
```

### Restore to clean state

```powershell
Stop-VM -Name ClaudeDevSandbox -Force
Restore-VMCheckpoint -VMName ClaudeDevSandbox -Name CleanProvisionedBase -Confirm:$false
```

---

## File structure

```
claude-sandbox-vm/
|-- Bootstrap.ps1              # One-time host setup
|-- Start-Session.ps1          # Daily session launcher
|
|-- scripts/
|   |-- New-ClaudeVM.ps1       # Creates the Hyper-V VM (Gen 2, TPM, Secure Boot)
|   |-- Install-Windows.ps1    # Applies Windows to VHDX via DISM (no DVD boot)
|   |-- Attach-ISO.ps1         # Alternative: boot from DVD if DISM not needed
|   |-- Start-Provision.ps1    # Host-side: switches network, copies files into VM
|   |-- Invoke-Provision.ps1   # VM-side: installs toolchain + Claude Code
|   |-- Save-BaseSnapshot.ps1  # Takes the clean base snapshot
|   |-- Save-VMCredentials.ps1 # Stores VM credentials encrypted on host
|   +-- Copy-Artifacts.ps1     # Extracts build outputs from VM to host
|
+-- vm/
    +-- Start-ClaudeCode.ps1   # Optional: VM startup script
```

---

## How it works

**Windows installation**: Instead of booting from DVD (which can fail with certain ISOs on Gen 2 VMs), `Install-Windows.ps1` mounts the ISO on the host, partitions the VHDX, and applies the image via DISM.

**Provisioning**: `Start-Provision.ps1` switches the VM to Default Switch for internet, copies the VS Build Tools cache and provision script via PowerShell Direct (VMBus -- no network needed), then you run the provisioner inside the VM.

**Sessions**: `Start-Session.ps1` copies your project into the VM via PowerShell Direct, optionally enables internet, and connects you to the console. Use `-Restore` for a clean-room build from snapshot.

**Artifacts**: `Copy-Artifacts.ps1` pulls build outputs from the VM to your host via PowerShell Direct.

---

## Networking

| Mode | Switch | Use case |
|------|--------|----------|
| Isolated (default) | Claude-Internal | No internet -- full sandbox |
| Internet | Default Switch | cargo fetch, npm install, OAuth |

Use `-Internet` flag on `Start-Session.ps1` to enable internet access.

---

## Troubleshooting

**PowerShell Direct connection fails**
Ensure the VM has finished booting and you've logged in at least once. PSRemoting must be enabled (done by Invoke-Provision.ps1).

**VM has no internet**
Use `-Internet` flag or manually switch: `Connect-VMNetworkAdapter -VMName ClaudeDevSandbox -SwitchName "Default Switch"`

**Re-authentication when OAuth expires**
Start the VM with internet, run `claude login` inside it, shut down, take a new snapshot.
