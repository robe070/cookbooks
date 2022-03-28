<#
.SYNOPSIS

Install the Cloud account id license

.DESCRIPTION

These tasks must all occur after Windows Updates. If they can be applied earlier, they should be applied earlier

.EXAMPLE


#>

param (
    [Parameter(Mandatory=$true)]
    [string]
    $GitRepoPath,
    [Parameter(Mandatory=$true)]
    [string]
    $CloudAccountLicense
)

try
{
    Write-Host( "Remove the Scalable license registry entrys")

    # Removing these keys means that when installing the LANSA msi they won't be found and the scalable license will not be activated.

    [string[][]]$Keys = @(@("LANSA Scalable License", "ScalableLicensePrivateKey"), @("LANSA Integrator License", "IntegratorLicensePrivateKey"), @("LANSA Development License", "DevelopmentLicensePrivateKey") )
    foreach ( $LicensePrivateKey in $Keys ) {
        $LicensePrivateKey[0]
        $LicensePrivateKey[1]
        Remove-ItemProperty -Path HKLM:\Software\LANSA  -Name $LicensePrivateKey[1] -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $LicenseDir =  "${env:ProgramFiles(x86)}\Common Files\LANSA"
    New-Item $LicenseDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path HKLM:\Software\lansa -Name Common –Force
    Set-ItemProperty -Path HKLM:\Software\lansa\Common -Name 'LicenseDir' -Value $LicenseDir | Out-Default | Write-Host
    $LicenseSource = "$GitRepoPath\scripts\$CloudAccountLicense"
    Write-Host( "Copying licenses from $LicenseSource...")
    Copy-Item -Path $LicenseSource -Destination $LicenseDir -Verbose | Write-Host

    Write-Host( "Successfuly setup the Cloud Account License")
}
catch
{
    $Global:LANSAEXITCODE = $LASTEXITCODE
    Write-Host "Remote-Script LASTEXITCODE = $LASTEXITCODE"
    Write-Host "install-cloud-account-id-license.ps1 is the <No file> in the stack dump below"
    throw
}