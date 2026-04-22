# scripts/Save-VMCredentials.ps1
# Run once on host. Saves VM login credentials securely for unattended artifact extraction.

$credPath = "$env:USERPROFILE\.claude-sandbox\vm-cred.xml"

Write-Host "Enter the username and password for the VM Windows account."
Write-Host "(This is the account you created during Windows setup inside the VM.)"
Write-Host ""

$cred = Get-Credential -Message "VM credentials"
$cred | Export-Clixml -Path $credPath

# Restrict access to current user only
icacls $credPath /inheritance:r /grant:r "$env:USERNAME:F" | Out-Null

Write-Host ""
Write-Host "Credentials saved to: $credPath"
Write-Host "Only your Windows account can read this file."
