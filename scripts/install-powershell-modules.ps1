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
# Pester for Testing
Write-Host "Installing Module Pester RequiredVersion 5.0.3" | Out-Default | Write-Verbose
Install-Module -Name Pester -RequiredVersion 5.0.3 -AllowClobber -Force
Write-Host "Installed Module Pester" | Out-Default | Write-Verbose

$Env:PsModuleInstalled = 'True'
