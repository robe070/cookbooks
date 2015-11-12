<#
.SYNOPSIS

Install SQL Server latest supported version.
Required because French AMI does not come with SQL Server pre-installed

.EXAMPLE


#>

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
    #####################################################################################
    Write-Output ("$(Log-Date) Download SQL Server") 

    $SqlServerFile = "$Script:ScriptTempPath\SQLServer.exe"
    $SqlServerUrl = "https://s3-ap-southeast-2.amazonaws.com/lansa/3rd+party/SQLEXPRWT_x64_FRA.exe"
    Write-Output ("Downloading $SqlServerUrl to $SqlServerFile")
    ( New-Object Net.WebClient ). DownloadFile($SqlServerUrl, $SqlServerFile)

    if ( Test-Path $SqlServerFile )
    {
        Write-Output ("Executing $SqlServerFile")

        # Set the current directory so that the install image gets unzipped there.
        cd $Script:ScriptTempPath

        Write-Output ("$(Log-Date) Installing SQL Server") 
        cmd /c $SqlServerFile /q /HIDECONSOLE /ACTION=Install /INSTANCENAME=MSSQLSERVER /FEATURES=SQLENGINE,SSMS /IAcceptSQLServerLicenseTerms=true  `
                /TCPENABLED=1 /ADDCURRENTUSERASSQLADMIN=true | Write-Output
    }
    else
    {
        Write-Error ("$SqlServerFile does not exist")
        throw ("$SqlServerFile does not exist")
    }
    Write-Output ("$(Log-Date) French SQL Server installation completed successfully")
    # Successful completion so set Last Exit Code to 0
    cmd /c exit 0
}
catch
{
	$_
    Write-Error ("$(Log-Date) French Base installation error")
    throw
}
