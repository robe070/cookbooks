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

Write-Host("Install a specific version of AWSPowershell as the automatically installed version (5.0.5) is broken. Grant-EC2SecurityGroupIngress is failing due to IpRanges not being part of the object Amazon.EC2.Model.IpPermission. Version 4.1.554 just happened to be the version that my dev box was using and I knew it worked.")
try {
    Get-Command Grant-EC2SecurityGroupIngress | Select-Object Name, Module  | Out-Default | Write-Host
    Write-Host("Grant-EC2SecurityGroupIngress is installed")
    try {
        Get-Module -ListAvailable -Name AWSPowerShell | Select-Object Name, Version, Path   | Out-Default | Write-Host
        UnInstall-Module -Name AWSPowerShell | Out-Default | Write-Host
    } catch {
        $_
        throw
    }
} catch {
    Write-Host("Grant-EC2SecurityGroupIngress is not installed")
}
Install-Module -Name AWSPowerShell -RequiredVersion 4.1.554 -AllowClobber -Force | Out-Default | Write-Host

# Pester for Testing
Write-Host "Installing Module Pester RequiredVersion 5.6.1" | Out-Default | Write-Verbose
Install-Module -Name Pester -RequiredVersion 5.6.1 -AllowClobber -Force
Write-Host "Installed Module Pester" | Out-Default | Write-Verbose

$Env:PsModuleInstalled = 'True'
