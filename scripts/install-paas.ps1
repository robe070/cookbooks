<#
.SYNOPSIS

Install a LANSA PaaS.

Installs a WebServer installation - a Companion system for the Applications
Installs n Applications app1, app2, ...,appn which configure the Companion system to redirect 
alias requests for app1, app2, ..., appn to the appropriate application.

Requires the LANSA AMI Scalable license

# N.B. It is vital that the user id and password supplied pass the password rules. 
E.g. The password is sufficiently complex and the userid is not duplicated in the password. 
i.e. UID=PCXUSER and PWD=PCXUSER@#$%^&* is invalid as the password starts with the entire user id "PCXUSER".

.EXAMPLE

1. Upload msi to c:\lansa\MyApp.msi (Copy file from local machine. Paste into RDP session)
2. Start SQL Server Service and set to auto start. Change SQL Server to accept SQL Server Authentication
3. Create lansa database
4. Add user lansa with password 'Pcxuser@122' to SQL Server as Sysadmin and to the lansa database as dbowner
5. Change server_name to the machine name in this command line and run it:
C:\\LANSA\\scripts\\install-lansa-msi.ps1 -server_name "IP-AC1F2F2A" -dbname "lansa" -dbuser "lansa" -dbpassword "Pcxuser@122" -webuser "pcxuser" -webpassword "Lansa@122"

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
[String]$LansaMSI,
[String]$trace = 'N',
[String]$traceSettings = "ITRO:Y ITRL:4 ITRM:9999999999",
[String]$ApplCount = ""
[String]$ApplMSIuri = ""
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

Write-Output "$(Log-Date) Constructing LANSA PaaS environment"

if ( $f32bit -eq 'true' -or $f32bit -eq '1')
{
    $f32bit_bool = $true
}
else
{
    $f32bit_bool = $false
}

$ApplName = "WebServer"
if ($f32bit_bool)
{
    $APPA = "${ENV:ProgramFiles(x86)}\$($ApplName)"
}
else
{
    $APPA = "${ENV:ProgramFiles}\$($ApplName)"
}

& "$script:IncludeDir\install-lansa-msi.ps1" -server_name $server_name -dbname $dbname -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -f32bit $f32bit -SUDB $SUDB -UPGD $UPGD -userscripthook $userscripthook -wait $wait -ApplName $ApplName -MSIuri $LansaMSI

For ( $i = 1; $i -le $ApplCount; $i++) {
    & "$script:IncludeDir\install-lansa-msi.ps1" -server_name $server_name -dbname $dbname -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -f32bit $f32bit -SUDB $SUDB -UPGD $UPGD -userscripthook $userscripthook -wait $wait -ApplName "app$i" -CompanionInstallPath $APPA -MSIuri "$ApplMSIuri/app$($i)_v14.2.0_en-us.msi"
}