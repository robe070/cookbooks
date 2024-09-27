if ("$($ENV:GITBRANCH)".Contains("refs/heads")) {
    $branch ="$($ENV:GITBRANCH)".replace("refs/heads/", "")
} else {
    $branch = "$($ENV:GITBRANCH)"
}
$branch | Write-Host | Out-Default | Write-Verbose
Write-Host "##vso[task.setvariable variable=GitBranch]$branch" | Out-Default | Write-Verbose
if ($Env:PsModuleInstalled -eq 'True') {
    Write-Host "PS Module already installed, skip the Install PS Module Task." | Out-Default | Write-Verbose
    return;
}

Write-Host "Installing Module AzureRM" | Out-Default | Write-Verbose
Install-Module -Name AzureRM -AllowClobber -Force
Write-Host "Installed Module AzureRM" | Out-Default | Write-Verbose

Write-Host "Installing Module Az.KeyVault  -RequiredVersion 2.0.0" | Out-Default | Write-Verbose
Install-Module -Name Az.KeyVault -RequiredVersion 2.0.0 -AllowClobber -Force | Out-Default | Write-Host | Write-Verbose
Write-Host "Installed Module Az.KeyVault  -RequiredVersion 2.0.0" | Out-Default | Write-Verbose

# Az.Accounts for Get-AzVMImage
Write-Host "Installing Module Az.Accounts -RequiredVersion 1.9.2" | Out-Default | Write-Verbose
Install-Module -Name Az.Accounts -RequiredVersion 1.9.2 -Force -AllowClobber | Out-Default | Write-Host | Write-Verbose
Write-Host "Installed Module Az.Accounts -RequiredVersion 1.9.2" | Out-Default | Write-Verbose

# Az.Compute for Connect-AzAccount
Write-Host "Installing Module Az.Compute -RequiredVersion 4.2.1" | Out-Default | Write-Verbose
Install-Module -Name Az.Compute -RequiredVersion 4.2.1 -Force -AllowClobber | Out-Default | Write-Host | Write-Verbose
Write-Host "Installed Module Az.Compute -RequiredVersion 4.2.1" | Out-Default | Write-Verbose

# Az.Resources for Get-AzResource
Write-Host "Installing Module Az.Resources -RequiredVersion 2.4.0" | Out-Default | Write-Verbose
Install-Module -Name Az.Resources -RequiredVersion 2.4.0 -Force -AllowClobber | Out-Default | Write-Host | Write-Verbose
Write-Host "Installed Module Az.Resources -RequiredVersion 2.4.0" | Out-Default | Write-Verbose

# Az for Azure Modules
Write-Host "Installing Module Az -RequiredVersion 4.5.0" | Out-Default | Write-Verbose
Install-Module -Name Az -RequiredVersion 4.5.0 -AllowClobber -Force | Out-Default | Write-Host | Write-Verbose
Write-Host "Installed Module Az -RequiredVersion 4.5.0" | Out-Default | Write-Verbose

# Pester for Testing
Write-Host "Installing Module Pester RequiredVersion 5.6.1" | Out-Default | Write-Verbose
Install-Module -Name Pester -RequiredVersion 5.6.1 -AllowClobber -Force
Write-Host "Installed Module Pester" | Out-Default | Write-Verbose

$Env:PsModuleInstalled = 'True'
