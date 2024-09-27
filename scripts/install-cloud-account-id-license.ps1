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
        $LicensePrivateKey[0] | Write-Host
        $LicensePrivateKey[1] | Write-Host
        Remove-ItemProperty -Path HKLM:\Software\LANSA  -Name $LicensePrivateKey[1] -Force -ErrorAction SilentlyContinue | Out-Null
    }

    $LicenseDir =  "${env:ProgramFiles(x86)}\Common Files\LANSA"
    if ( -not (Test-Path $LicenseDir)) {
        Write-Host( "Creating directory $LicenseDir")
        New-Item $LicenseDir -ItemType Directory -ErrorAction SilentlyContinue  | Out-Default | Write-Host
    } else {
        Write-Host( "$LicenseDir already exists")
    }

    $RegKey = "HKLM:\Software\lansa\Common"
    if ( -not (Test-Path $RegKey) ) {
        Write-Host( "Creating registry entry $RegKey")
        New-Item -Path HKLM:\Software\lansa -Name Common | Out-Default | Write-Host
    } else {
        Write-Host( "$RegKey already exists")
    }

    $RegProperty = "LicenseDir"
    Write-Host( "Creating registry value $RegProperty")
    Set-ItemProperty -Path $RegKey -Name $RegProperty -Value $LicenseDir | Out-Default | Write-Host

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