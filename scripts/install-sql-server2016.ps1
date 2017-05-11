<#
.SYNOPSIS

Install SQL Server latest supported version.
Required when cloud image does not come with SQL Server pre-installed

.EXAMPLE


#>

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

# If environment not yet set up, it should be running locally, not through Remote PS
if ( -not $script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Output "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Output "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

try {
    if (!(Test-Path -Path $Script:ScriptTempPath)) {
        New-Item -ItemType directory -Path $Script:ScriptTempPath
    }

    #####################################################################################
    Write-Output ("$(Log-Date) Download SQL Server") 

    $SqlServerFile = "$Script:ScriptTempPath\SQLServer.exe"
    $SqlServerUrl = "https://s3-ap-southeast-2.amazonaws.com/lansa/3rd+party/SQLServer2016-SSEI-Dev.exe"
    Write-Output ("Downloading $SqlServerUrl to $SqlServerFile")
    ( New-Object Net.WebClient ). DownloadFile($SqlServerUrl, $SqlServerFile)

    if ( Test-Path $SqlServerFile )
    {
        Write-Output ("$(Log-Date) Installing .Net Framework ")

        Install-WindowsFeature Net-Framework-Core

        # Note that Desktop-Experience cannot be installed prior to installing SQL Server as the sysprep will fail
        # e.g. taking the base Azure Microsoft VM "Windows Server 2012 Datacenter" and installing it and sysprep fails
        # Install-WindowsFeature Desktop-Experience
        
        Write-Output ("$(Log-Date) Executing $SqlServerFile")

        # Set the current directory so that the install image gets unzipped there.
        cd $Script:ScriptTempPath

        Write-Output ("$(Log-Date) Sysprep SQL Server") 
#        cmd /c $SqlServerFile /qs /ACTION=Install /INSTANCENAME=MSSQLSERVER `
#                /FEATURES=SQLENGINE,SSMS /IAcceptSQLServerLicenseTerms=true  `
#                /TCPENABLED=1 /ADDCURRENTUSERASSQLADMIN=true `
#                /SQLSYSADMINACCOUNTS="AUTORITE NT\SERVICE RÉSEAU" `
#                /SQLSVCACCOUNT="AUTORITE NT\SERVICE RÉSEAU" `
#                /AGTSVCACCOUNT="AUTORITE NT\SERVICE RÉSEAU" | Write-Output

        cmd /c $SqlServerFile /Q /ACTION="PrepareImage" /INDICATEPROGRESS="false" /INSTANCEID="MSSQLSERVER" `
                /FEATURES=SQLENGINE,FULLTEXT,CONN,SSMS /IAcceptSQLServerLicenseTerms=true | Write-Output

        cp "$script:IncludeDir\SetupComplete2.cmd" -Destination "$env:SystemRoot\OEM"
    }
    else
    {
        Write-Error ("$SqlServerFile does not exist")
        throw ("$SqlServerFile does not exist")
    }
    Write-Output ("$(Log-Date) SQL Server installation completed successfully")

    PlaySound

    # Successful completion so set Last Exit Code to 0
    cmd /c exit 0
}
catch
{
	$_
    Write-Error ("$(Log-Date) SQL Server installation error")
    PlaySound
    throw
}
