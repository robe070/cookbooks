<#
.SYNOPSIS

Install the LANSA IDE.
Creates a SQL Server Database then installs from the DVD image

Requires the environment that a LANSA Cake provides, particularly an AMI license.

# N.B. It is vital that the user id and password supplied pass the password rules.
E.g. The password is sufficiently complex and the userid is not duplicated in the password.
i.e. UID=PCXUSER and PWD=PCXUSER@#$%^&* is invalid as the password starts with the entire user id "PCXUSER".

.EXAMPLE


#>
param (
    [Parameter(Mandatory=$true)]
    [string]
    $GitRepoPath_,

    [Parameter(Mandatory=$true)]
    [string]
    $TempPath_,

    [Parameter(Mandatory=$true)]
    [string]
    $LicenseKeyPassword_
    )

# If environment not yet set up, it should be running locally, not through Remote PS
if ($true) {
    if ( -not $script:IncludeDir)
    {
        # Log-Date can't be used yet as Framework has not been loaded

	    Write-Host "Initialising environment - presumed not running through RemotePS"
	    $MyInvocation.MyCommand.Path
	    $script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	    . "$script:IncludeDir\Init-Baking-Vars.ps1"
	    . "$script:IncludeDir\Init-Baking-Includes.ps1"
    }
    else
    {
	    Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS"
    }
}
else {
	Write-Host "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}

try
{
    # read the cloud value
    $lansaKey = 'HKLM:\Software\LANSA\'
    $Cloud = (Get-ItemProperty -Path $lansaKey -Name 'Cloud').Cloud
    # read the Version Major and Minor value
    $VersionMajor = (Get-ItemProperty -Path $lansaKey -Name 'VersionMajor').VersionMajor
    $VersionMinor = (Get-ItemProperty -Path $lansaKey -Name 'VersionMinor').VersionMinor
   
    # Check if SQL Server is installed
    $mssql_services = Get-WmiObject win32_service | where-object name -like 'MSSQL*'
    If ( $mssql_services ) {

        #####################################################################################
        Write-Host ("$(Log-Date) Enable Named Pipes on local database")
        #####################################################################################

        Import-Module “sqlps” -DisableNameChecking | Out-Host

        Write-Host( "$(Log-Date) Comment out adding named pipe support to local database because it switches off output in this remote session")
        Change-SQLProtocolStatus -server $env:COMPUTERNAME -instance "MSSQLSERVER" -protocol "NP" -enable $true
        Set-Location "c:"

        #####################################################################################
        Write-Host "$(Log-Date) Set local SQL Server to manual"
        #####################################################################################

        Set-Service "MSSQLSERVER" -startuptype "manual" | Out-Host
    }

    #####################################################################################
    Write-Host "$(Log-Date) Installing License"
    #####################################################################################
    Write-Debug "Password: $licensekeypassword_" | Out-Host
    CreateLicence -licenseFile "$Script:ScriptTempPath\LANSAScalableLicense.pfx" -password $LicenseKeyPassword_ -dnsName "LANSA Scalable License" -registryValue "ScalableLicensePrivateKey" | Out-Host
    CreateLicence -licenseFile "$Script:ScriptTempPath\LANSAIntegratorLicense.pfx" -password $LicenseKeyPassword_ -dnsName "LANSA Integrator License" -registryValue "IntegratorLicensePrivateKey" | Out-Host

    Test-RegKeyValueIsNotNull 'IntegratorLicensePrivateKey'

    #####################################################################################
    Write-Host ("$(Log-Date) Shortcuts")
    #####################################################################################

    # Verify if the ScalableStartHere.htm is present for the Lansa Version
    if (!(Test-Path -Path "$Script:GitRepoPath\Marketplace\LANSA Scalable License\$Cloud\$VersionMajor.$VersionMinor"))  {

        throw "ScalableStartHere.htm for $Cloud\$VersionMajor.$VersionMinor combination does not exist"
    }
    else {
        copy-item "$Script:GitRepoPath\Marketplace\LANSA Scalable License\$Cloud\$VersionMajor.$VersionMinor\ScalableStartHere.htm" "$ENV:ProgramFiles\CloudStartHere.htm" | Out-Host
    }
  
    New-Shortcut "${ENV:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe" "CommonDesktop\Start Here.lnk" -Description "Start Here"  -Arguments "`"file://$ENV:ProgramFiles/CloudStartHere.htm`"" -WindowStyle "Maximized" | Out-Host

    New-Shortcut "${ENV:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe" "CommonDesktop\Education.lnk" -Description "Education"  -Arguments "http://www.lansa.com/education/" -WindowStyle "Maximized" | Out-Host

    Remove-ItemProperty -Path HKLM:\Software\LANSA -Name StartHereShown –Force -ErrorAction SilentlyContinue | Out-Null

    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "StartHere" -Value "powershell -executionpolicy Bypass -file $Script:GitRepoPath\scripts\show-start-here.ps1" | Out-Host

    Test-RegKeyValueIsNotNull 'IntegratorLicensePrivateKey'

    Add-TrustedSite "lansa.com" | Out-Host
    Add-TrustedSite "google-analytics.com" | Out-Host
    Add-TrustedSite "googleadservices.com" | Out-Host
    Add-TrustedSite "img.en25.com" | Out-Host
    Add-TrustedSite "addthis.com" | Out-Host
    Add-TrustedSite "*.lansa.myabsorb.com" | Out-Host
    Add-TrustedSite "*.cloudfront.com" | Out-Host

    Test-RegKeyValueIsNotNull 'IntegratorLicensePrivateKey'

    Write-Host ("$(Log-Date) Installation completed successfully")
}
catch
{
    Write-RedOutput ("$(Log-Date) Installation error") | Out-Host

    $Global:LANSAEXITCODE = $LASTEXITCODE
    Write-RedOutput "Remote-Script LASTEXITCODE = $LASTEXITCODE" | Out-Host

    Write-RedOutput "install-lansa-scalable.ps1 is the <No file> in the stack dump below" | Out-Host
    throw
}

# Successful completion so set Last Exit Code to 0
cmd /c exit 0
