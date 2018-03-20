<#
.SYNOPSIS

Reinstall an application in a LANSA PaaS.

Uninstalls Applications n.
Drops the database
Creates the databsae
Installs Application n

Requires the LANSA AMI Scalable license

# N.B. It is vital that the user id and password supplied pass the password rules. 
E.g. The password is sufficiently complex and the userid is not duplicated in the password. 
i.e. UID=PCXUSER and PWD=PCXUSER@#$%^&* is invalid as the password starts with the entire user id "PCXUSER".

.EXAMPLE

#>
param(
[String]$server_name='robertpc\sqlserver2012',
[String]$dbname='test1',
[String]$dbuser = 'admin',
[String]$dbpassword = 'password',
[String]$webuser = 'PCXUSER2',
[String]$webpassword = 'PCXUSER@122',
[String]$f32bit = 'true',
[String]$SUDB = '1',
[String]$UPGD = 'false',
[String]$maxconnections = '20',
[String]$wait,
[String]$userscripthook,
[Parameter(Mandatory=$false)]
[String]$DBUT='MSSQLS',
[String]$MSIuri,
[String]$trace = 'N',
[String]$traceSettings = "ITRO:Y ITRL:4 ITRM:9999999999",
[String]$ApplNumber = "",
[String]$ApplMSIuri = "",
[String]$HTTPPortNumber = "",
[String]$HostRoutePortNumber = "",
[String]$JSMPortNumber = "",
[String]$JSMAdminPortNumber = "",
[String]$HTTPPortNumberHub = ""
)

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

Write-Output "$(Log-Date) Reinstalling Application $ApplNumber in LANSA PaaS environment"

Write-Output("$(Log-Date) Script Directory: $script:IncludeDir")

if ( $f32bit -eq 'true' -or $f32bit -eq '1')
{
    $f32bit_bool = $true
}
else
{
    $f32bit_bool = $false
}

if ( $UPGD -eq 'true' -or $UPGD -eq '1')
{
    $UPGD_bool = $true
}
else
{
    $UPGD_bool = $false
}

cmd /c exit 0    #Set $LASTEXITCODE

try {
    $ApplName = "WebServer"
    if ($f32bit_bool) {
        $APPA = "${ENV:ProgramFiles(x86)}\$($ApplName)"
    } else {
        $APPA = "${ENV:ProgramFiles}\$($ApplName)"
    }
    Write-Output( "$(Log-Date) Companion Install Path $APPA" )

    $ApplName = "APP$ApplNumber"
    Write-Output( "$(Log-Date) Uninstalling application $ApplName")
    & "$script:IncludeDir\uninstall-lansa-msi.ps1" -DBUT $DBUT -server_name $server_name -dbname $ApplName -dbuser $dbuser -dbpassword $dbpassword $webpassword -f32bit $f32bit -SUDB $SUDB -wait $wait -ApplName $ApplName -CompanionInstallPath $APPA    

    Write-Output( "$(Log-Date) Installing $ApplName")
    & "$script:IncludeDir\install-lansa-msi.ps1" -server_name $server_name -dbname $ApplName -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -f32bit $f32bit -SUDB $SUDB -UPGD $UPGD -userscripthook $userscripthook -wait $wait -ApplName $ApplName -CompanionInstallPath $APPA -MSIuri "$ApplMSIuri/$($ApplName)_v1.0.0_en-us.msi" $HTTPPortNumber -HostRoutePortNumber $HostRoutePortNumber -JSMPortNumber $JSMPortNumber -JSMAdminPortNumber $JSMAdminPortNumber -HTTPPortNumberHub $HTTPPortNumberHub -GitRepoUrl "git@github.com:lansa/lansaeval$($ApplNumber).git"    
   
    if ($LASTEXITCODE -eq 0 ) {
        iisreset
    } else {
        Write-Output( "$(Log-Date) throwing")
        throw
    }
} catch {
    $e = $_.Exception
    $e | format-list -force
 
    Write-Output( "Application $ApplName reinstallation failed" )
    Write-Output( "Raw LASTEXITCODE $LASTEXITCODE" )
    if ( ( -not [ string ]::IsNullOrWhiteSpace( $LASTEXITCODE ) ) -and ( $LASTEXITCODE -ne 0 ) )
    {
       $ExitCode = $LASTEXITCODE
       Write-Output( "ExitCode set to LASTEXITCODE $ExitCode" )
    } else {
       $ExitCode = $e.HResult
       Write-Output( "ExitCode set to HResult $ExitCode" )
    }
 
    if ( $ExitCode -eq $null -or $ExitCode -eq 0 )
    {
       $ExitCode = -1
       Write-Output( "ExitCode set to $ExitCode" )
    }
    Write-Output( "Final ExitCode $ExitCode" )
    cmd /c exit $ExitCode    #Set $LASTEXITCODE
    Write-Output( "Final LASTEXITCODE $LASTEXITCODE" )
    return
 }
 Write-Output( "Application $ApplName reinstallation succeeded" )
 cmd /c exit 0    #Set $LASTEXITCODE
 Write-Output( "LASTEXITCODE $LASTEXITCODE" )