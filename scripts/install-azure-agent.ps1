# scripts/install-azure-agent.ps1
param (
    [string]$vmName,
    [string]$adminUsername,
    [string]$adminPassword,
    [string]$AzurePAT
)

$LogFile = "C:\adoagent\install-log.txt"
Start-Transcript -Path $LogFile -Force -IncludeInvocationHeader

if (-not (Test-Path C:\adoagent)) {
    Write-Host "Installing agent on: $vmName"

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri https://vstsagentpackage.azureedge.net/agent/2.227.2/vsts-agent-win-x64-2.227.2.zip -OutFile agent.zip
    Expand-Archive agent.zip -DestinationPath C:\adoagent
    cd C:\adoagent

    .\config.cmd --unattended --url https://dev.azure.com/VisualLansa `
      --auth pat --token $AzurePAT `
      --pool Default --agent $vmName --acceptTeeEula --runAsService `
      --windowsLogonAccount $adminUsername --windowsLogonPassword $adminPassword

    # Optional start
    # .\svc install
    # .\svc start
} else {
    Write-Host 'Agent already installed. Skipping.'
}

# Ensure correct version of Pester
if (Test-Path 'C:\Program Files\WindowsPowerShell\Modules\Pester\3.4.0') {
    Rename-Item -Path 'C:\Program Files\WindowsPowerShell\Modules\Pester\3.4.0' -NewName '3.4.0-disabled'
    Install-Module Pester -RequiredVersion 5.6.1 -Scope AllUsers -Force -AllowClobber -SkipPublisherCheck
} else {
    Write-Host 'Correct Pester version already installed. Skipping.'
}

Stop-Transcript

Get-Contents $LogFile | Write-Host