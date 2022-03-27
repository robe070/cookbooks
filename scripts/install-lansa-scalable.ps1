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
    $TempPath_
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

        Import-Module “sqlps” -DisableNameChecking | Out-Default | Write-Host
        $InstanceName = Get-SqlServerInstanceName -server $env:COMPUTERNAME
        $ServiceName = Get-SqlServerServiceName -server $env:COMPUTERNAME
        Change-SQLProtocolStatus -server $env:COMPUTERNAME -instance $InstanceName -protocol "NP" -enable $true
        Set-Location "c:"

        #####################################################################################
        Write-Host "$(Log-Date) Set local SQL Server to manual"
        #####################################################################################

        Set-Service $ServiceName -startuptype "manual" | Out-Default | Write-Host
    }

    if ( -Not $script:InstallCloudAccountLicense ) {

        #####################################################################################
        Write-Host "$(Log-Date) Installing License"
        #####################################################################################
        # Write-Debug "Password: $licensekeypassword_" | Out-Default | Write-Host
        CreateLicence -awsParameterStoreName "LANSAScalableLicense.pfx"  -dnsName "LANSA Scalable License" -registryValue "ScalableLicensePrivateKey" | Out-Default | Write-Host
        CreateLicence -awsParameterStoreName "LANSAIntegratorLicense.pfx"  -dnsName "LANSA Integrator License" -registryValue "IntegratorLicensePrivateKey" | Out-Default | Write-Host

        Test-RegKeyValueIsNotNull 'IntegratorLicensePrivateKey'
    }

    #####################################################################################
    Write-Host ("$(Log-Date) Shortcuts")
    #####################################################################################

    # Verify if the ScalableStartHere.htm is present for the Lansa Version
    if (!(Test-Path -Path "$GitRepoPath_\Marketplace\LANSA Scalable License\$Cloud\$VersionMajor.$VersionMinor"))  {
        throw "ScalableStartHere.htm for $Cloud\$VersionMajor.$VersionMinor combination does not exist"
    }
    else {
        copy-item "$GitRepoPath_\Marketplace\LANSA Scalable License\$Cloud\$VersionMajor.$VersionMinor\ScalableStartHere.htm" "$ENV:ProgramFiles\CloudStartHere.htm" | Out-Default | Write-Host
        copy-item "$GitRepoPath_\Marketplace\LANSA Scalable License\$Cloud\$VersionMajor.$VersionMinor\ScalableStartHere.htm" "${ENV:ProgramFiles(x86)}\CloudStartHere.htm" | Out-Default | Write-Host
    }

    try {
        New-Shortcut "$ENV:ProgramFiles\Google\Chrome\Application\chrome.exe" "CommonDesktop\Start Here.lnk" -Description "Start Here"  -Arguments "`"file://$ENV:ProgramFiles/CloudStartHere.htm`"" -WindowStyle "Maximized" | Out-Default | Write-Host
    } catch {
        Write-RedOutput $_ | Out-Default | Write-Host
        Write-RedOutput $PSItem.ScriptStackTrace | Out-Default | Write-Host

        Write-RedOutput ("$(Log-Date) Retrying with the Program Files X86 Target Path") | Out-Default | Write-Host
        New-Shortcut "${ENV:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe" "CommonDesktop\Start Here.lnk" -Description "Start Here"  -Arguments "`"file://$ENV:ProgramFiles/CloudStartHere.htm`"" -WindowStyle "Maximized" | Out-Default | Write-Host
    }

    try {
        New-Shortcut "$ENV:ProgramFiles\Google\Chrome\Application\chrome.exe" "CommonDesktop\Education.lnk" -Description "Education"  -Arguments "http://www.lansa.com/education/" -WindowStyle "Maximized" | Out-Default | Write-Host
    } catch {
        Write-RedOutput $_ | Out-Default | Write-Host
        Write-RedOutput $PSItem.ScriptStackTrace | Out-Default | Write-Host

        Write-RedOutput ("$(Log-Date) Retrying with the Program Files X86 Target Path") | Out-Default | Write-Host
        New-Shortcut "${ENV:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe" "CommonDesktop\Start Here.lnk" -Description "Start Here"  -Arguments "`"file://$ENV:ProgramFiles/CloudStartHere.htm`"" -WindowStyle "Maximized" | Out-Default | Write-Host
    }
    Remove-ItemProperty -Path HKLM:\Software\LANSA -Name StartHereShown –Force -ErrorAction SilentlyContinue | Out-Null

    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "StartHere" -Value "powershell -executionpolicy Bypass -file $GitRepoPath_\scripts\show-start-here.ps1" | Out-Default | Write-Host

    Test-RegKeyValueIsNotNull 'IntegratorLicensePrivateKey'

    Add-TrustedSite "lansa.com" | Out-Default | Write-Host
    Add-TrustedSite "google-analytics.com" | Out-Default | Write-Host
    Add-TrustedSite "googleadservices.com" | Out-Default | Write-Host
    Add-TrustedSite "img.en25.com" | Out-Default | Write-Host
    Add-TrustedSite "addthis.com" | Out-Default | Write-Host
    Add-TrustedSite "*.lansa.myabsorb.com" | Out-Default | Write-Host
    Add-TrustedSite "*.cloudfront.com" | Out-Default | Write-Host

    Test-RegKeyValueIsNotNull 'IntegratorLicensePrivateKey'

    Write-Host ("$(Log-Date) Installation completed successfully")
}
catch
{
    Write-RedOutput $_ | Out-Default | Write-Host
    Write-RedOutput $PSItem.ScriptStackTrace | Out-Default | Write-Host

    Write-RedOutput ("$(Log-Date) Installation error") | Out-Default | Write-Host

    $Global:LANSAEXITCODE = $LASTEXITCODE
    Write-RedOutput "Remote-Script LASTEXITCODE = $LASTEXITCODE" | Out-Default | Write-Host

    Write-RedOutput "install-lansa-scalable.ps1 is the <No file> in the stack dump below" | Out-Default | Write-Host
    throw
}

# Successful completion so set Last Exit Code to 0
cmd /c exit 0
