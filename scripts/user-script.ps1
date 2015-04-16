<#
.SYNOPSIS

Example user script executed at end of LANSA MSI Install

The same parameters are passed to this script as are passed to the caller, install-lansa-msi.ps1

Git Test 2
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
[String]$userscripthook
)
try
{
    $DebugPreference = "Continue"
    $VerbosePreference = "Continue"
    Write-Verbose ("Previous 2 lines display Debug and Verbose messages")

    Write-Verbose ("Use Write-Verbose instead of comments. Then they can be useful in the log, and not just to the programmer writing the script")

    Write-Verbose ("Use Write-Output for messages that should always be displayed. E.g. Major steps in the process")
    Write-Output ( "User Script started")

    Write-Output ("Executing $userscripthook")

    Write-Verbose ("Use Write-Debug for debug messages, duh!")
    Write-Debug ("Server_name = $server_name")
    Write-Debug ("dbname = $dbname")
    Write-Debug ("dbuser = $dbuser")
    Write-Debug ("webuser = $webuser")
    Write-Debug ("32bit = $f32bit")
    Write-Debug ("SUDB = $SUDB")
    Write-Debug ("UPGD = $UPGD")

    Write-Output ( "User Script completed successfully")
}
catch
{
    Write-Error ( "User Script failed")
}
